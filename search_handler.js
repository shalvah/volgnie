const Honeybadger = require('@honeybadger-io/js');
Honeybadger.configure({
    apiKey: process.env.HONEYBADGER_API_KEY,
});
const chromium = require('chrome-aws-lambda');

exports.searchTwitter = async (event, context) => {
    // Support HTTP invocation or direct invocation
    const payload = typeof event.body === "string" ? JSON.parse(event.body) : event.body;
    const query = payload.query;
    if (!query) {
        throw new Error("No search query");
    }

    const browser = await chromium.puppeteer.launch({
        executablePath: process.env.CHROMIUM_EXECUTABLE || await chromium.executablePath,
        args: [
            // See https://filipvitas.medium.com/how-to-set-user-agent-header-with-puppeteer-js-and-not-fail-28c7a02165da
            process.platform === "win32"
                ? "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.93 Safari/537.36"
                : "--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/92.0.4512.0 Safari/537.36"
        ],
        headless: true
    });
    const page = await browser.newPage();
    page.on('console', (msg) => console.log('PAGE LOG:', msg.text()));
    await searchTwitterWebsite(page, query);

    if (payload.checkExistenceOnly) {
        let results = await page.$('article');
        if (!results) {
            console.log("Second try");
            // Try again to be sure. For some reason, it returns "No results" sometimes
            await searchTwitterWebsite(page, query);
            results = await page.$('article');
        }

        if (payload.__screenshot) {
            let filename = query.replace(/[: ]/g, "_");
            await page.screenshot({
                path: `_${filename}.png`,
            });
        }

        const exists = !!results;
        await browser.close();
        return {
            exists
        };
    }

    // Currently, this scrolls to the bottom, but capture only some results
    // todo: figure out how to capture all results
    // idea: scroll, while capturing
    await scrollToBottomOfResults(page);
    if (payload.__screenshot) {
        let filename = query.replace(/[: ]/g, "_");
        await page.screenshot({
            path: `_${filename}.png`,
            captureBeyondViewport: true,
            fullPage: true
        });
    }
    const tweetLinks = await page.$$eval('article a time', timeElements => {
        return timeElements.map(t => {
            return t.parentElement.getAttribute("href");
        });
    });
    await browser.close();

    return {
        results: tweetLinks
    };
};

async function searchTwitterWebsite(page, query) {
    await page.goto("https://mobile.twitter.com/explore", {waitUntil: 'networkidle2'});
    await page.waitForTimeout(3000);
    await page.type("input[type=text][aria-label=\"Search query\"]", query);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1000);
    const tabs = await page.$$("a[role=tab]");
    await tabs[1].click(); // "Latest" tab
    await page.waitForTimeout(1000);
}

async function scrollToBottomOfResults(page) {
    await page.evaluate(async () => {
        await new Promise((resolve, reject) => {
            let totalHeight = 0;
            const distance = 100;
            const timer = setInterval(() => {
                const scrollHeight = document.body.scrollHeight;
                window.scrollBy(0, distance);
                totalHeight += distance;

                if (totalHeight >= scrollHeight) {
                    clearInterval(timer);
                    resolve();
                }
            }, 400);
        });
    });
}