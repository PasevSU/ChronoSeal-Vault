import assert from 'node:assert/strict';
import { splitEmailForWkd, buildWkdUrls } from '../server/wkd-utils.js';

const known = splitEmailForWkd('Joe.Doe@Example.ORG');
assert.equal(known.localMapped, 'joe.doe');
assert.equal(known.domain, 'example.org');
assert.equal(known.hu, 'iy9q119eutrkn8s1mk4r39qejnbu3n5q');
const urls = buildWkdUrls('Joe.Doe@Example.ORG');
assert.equal(urls.advancedUrl, 'https://openpgpkey.example.org/.well-known/openpgpkey/example.org/hu/iy9q119eutrkn8s1mk4r39qejnbu3n5q?l=Joe.Doe');
assert.equal(urls.directUrl, 'https://example.org/.well-known/openpgpkey/hu/iy9q119eutrkn8s1mk4r39qejnbu3n5q?l=Joe.Doe');
console.log('[PASS] WKD z-base-32 and URL construction');
