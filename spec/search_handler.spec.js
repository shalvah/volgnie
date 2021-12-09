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
            assert.equal(result.exists, true, "Found no tweets when tweets exist");

            payload = {
                query: "from:jack to:theshalvah",
                checkExistenceOnly: true,
                __screenshot: !process.env.CI
            }
            result = await searchTwitter({body: payload}, {});
            console.log(result);
            assert.equal(result.exists, false, "Found tweets when NO tweets exist");
/*
            payload = {
                query: "from:jack until:2006-03-22",
                __screenshot: !process.env.CI // For debugging
            }
            let {results} = await searchTwitter({body: payload}, {});
            console.log(results);
            assert.equal(results.length, 4);
            assert.equal(results[0].id, "62");
            assert.equal(results[1].id, "51");
            assert.equal(results[2].id, "35");
            assert.equal(results[3].id, "29");*/
        }
    });
});