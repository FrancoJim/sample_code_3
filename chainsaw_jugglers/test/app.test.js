const { test, before, after } = require("node:test")
const assert = require("node:assert/strict")

const app = require("../app")

let server
let base

before(async () => {
  server = app.listen(0)
  await new Promise((resolve) => server.once("listening", resolve))
  base = `http://127.0.0.1:${server.address().port}`
})

after(() => server.close())

for (const route of ["/", "/about", "/classes", "/contact"]) {
  test(`GET ${route} serves an HTML page`, async () => {
    const res = await fetch(base + route)
    assert.equal(res.status, 200)
    assert.match(res.headers.get("content-type"), /text\/html/)
  })
}

test("static assets are served", async () => {
  const res = await fetch(`${base}/styles.css`)
  assert.equal(res.status, 200)
  assert.match(res.headers.get("content-type"), /text\/css/)
})

test("unknown routes return the custom 404 page", async () => {
  const res = await fetch(`${base}/no-such-page`)
  assert.equal(res.status, 404)
  assert.match(res.headers.get("content-type"), /text\/html/)
})

test("path traversal does not escape public/", async () => {
  const res = await fetch(`${base}/..%2fapp.js`)
  assert.equal(res.status, 404)
  assert.doesNotMatch(await res.text(), /require\("express"\)/)
})

test("does not advertise the framework", async () => {
  const res = await fetch(base)
  assert.equal(res.headers.get("x-powered-by"), null)
})
