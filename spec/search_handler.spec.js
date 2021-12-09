const assert = require('assert');
require('dotenv').config();
const {searchTwitter} = require("../search_handler");
require('@honeybadger-io/js').configure({
    reportData: false
});

describe('search', function () {
    it('works', async function () {
        this.timeout(60000)
        let runs = process.env.CI ? 3 : 1;
        while (runs--) {
            let query = "from:jack to:Twitter"
            let payload = {
                query: query,
                checkExistenceOnly: true,
                __screenshot: !process.env.CI // For debugging
            }
            let result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, true);

            payload = {
                query: "from:jack to:theshalvah",
                checkExistenceOnly: true,
                __screenshot: !process.env.CI // For debugging
            }
            result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, false);
/*
            payload = {
                query: "from:jack until:2006-03-22",
                __screenshot: !process.env.CI // For debugging
            }
            let {results} = await searchTwitter({body: payload}, {});
            console.log(results);
            assert.equal(results.length, 4);
            // "just setting up my twttr" doesn't show up :(
            assert.equal(results[0].text, "working on SMS in");
            assert.equal(results[1].text, "lunch");
            assert.equal(results[2].text, "waiting for dom to update more");
            assert.equal(results[3].text, "inviting coworkers");*/
        }
    });
});