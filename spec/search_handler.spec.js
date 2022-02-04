const assert = require('assert');
require('dotenv').config();
const {searchTwitter} = require("../search_handler");
require('@honeybadger-io/js').configure({
    reportData: false
});

describe('search', function () {
    it('works', async function () {
        this.timeout(600000)
        let runs = process.env.CI ? 3 : 1;

        for (let run = 1; run <= runs; run++) {
            let payload = {
                query: "from:jack to:Twitter",
                checkExistenceOnly: true,
                __screenshot: !process.env.CI // For debugging
            }
            let result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, true, `Run ${run} of ${runs}: Found no tweets for ${payload.query}`);

            payload = {
                query: "from:Twitter to:jack",
                checkExistenceOnly: true,
                __screenshot: !process.env.CI // For debugging
            }
            result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, true, `Run ${run} of ${runs}: Found no tweets for ${payload.query}`);

            payload = {
                query: "from:jack to:theshalvah",
                checkExistenceOnly: true,
                __screenshot: !process.env.CI
            }
            result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, false, `Run ${run} of ${runs}: Found tweets when NO tweets exist`);
        }


        for (let run = 1; run <= runs; run++) {
            let payload = {
                query: "from:jack until:2006-03-22",
                __screenshot: !process.env.CI // For debugging
            }
            let {results} = await searchTwitter({body: payload}, {});
            console.log(results);
            assert.equal(results.length, 4);
            assert.equal(results[0], "/jack/status/62");
            assert.equal(results[1], "/jack/status/51");
            assert.equal(results[2], "/jack/status/35");
            assert.equal(results[3], "/jack/status/29");

            // todo
            payload = {
                query: "from:Twitter until:2008-03-22",
                __screenshot: !process.env.CI // For debugging
            }
            results = await searchTwitter({body: payload}, {}).results;
            console.log(results);
        }
    });
});