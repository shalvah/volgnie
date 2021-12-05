const Honeybadger = require('@honeybadger-io/js');
Honeybadger.configure({
    apiKey: process.env.HONEYBADGER_API_KEY,
});
const puppeteer = require('puppeteer-core');
const chromium = require('chrome-aws-lambda');

exports.searchTwitter = Honeybadger.lambdaHandler(async (event, context) => {
    // Support HTTP invocation or direct invocation
    const payload = typeof event.body === "string" ? JSON.parse(event.body) : event.body;
    const query = payload.query;
    if(!query) {
        throw new Error("No search query");
    }

    const browser = await puppeteer.launch({
        executablePath: process.env.CHROMIUM_EXECUTABLE || await chromium.executablePath,
    });
    const page = await browser.newPage();
    await page.goto(`https://mobile.twitter.com/search/?q=${query}&f=live`);

    if (payload.checkExistenceOnly) {
        const results = await page.$$('article');
        await page.waitForTimeout(1000); // todo maybe wait until element appears
        const exists = results.length > 0;
        await browser.close();
        return {
            exists
        };
    }

    // Currently, this scrolls to the bottom, but capture only some results
    // Later: figure out how to capture all results
    await scrollToBottomOfResults(page);
    await page.screenshot({
        path: 'example.png',
        captureBeyondViewport: true,
        fullPage: true
    });
    const results = await page.$$('article a time');
    // const tweetLinks = results.map(timeElement => {
    //     timeElement.
    // });
    await browser.close();

    return {
        results: results
    };
});


async function scrollToBottomOfResults(page){
    await page.evaluate(async () => {
        await new Promise((resolve, reject) => {
            let totalHeight = 0;
            const distance = 100;
            const timer = setInterval(() => {
                const scrollHeight = document.body.scrollHeight;
                window.scrollBy(0, distance);
                totalHeight += distance;

                if (totalHeight >= scrollHeight){
                    clearInterval(timer);
                    resolve();
                }
            }, 400);
        });
    });
}