const path = require("path")
const express = require("express")

const app = express()
const publicDir = path.join(__dirname, "public")
const port = Number(process.env.PORT) || 8080

// Don't advertise the framework in every response
app.disable("x-powered-by")

const pages = {
  "/": "index.html",
  "/about": "about.html",
  "/classes": "classes.html",
  "/contact": "contact.html",
}

Object.entries(pages).forEach(([route, file]) => {
  app.get(route, (req, res) => {
    res.sendFile(path.join(publicDir, file))
  })
})

app.use(express.static(publicDir))

app.use((req, res) => {
  res.status(404).sendFile(path.join(publicDir, "404.html"))
})

if (require.main === module) {
  const server = app.listen(port, "0.0.0.0", () => {
    console.log(`Server listening on http://0.0.0.0:${port}`)
  })

  // Node as PID 1 ignores SIGTERM by default, so Docker/Cloud Run would wait out the
  // grace period and SIGKILL mid-request. Stop accepting connections and exit cleanly.
  for (const signal of ["SIGTERM", "SIGINT"]) {
    process.on(signal, () => {
      console.log(`${signal} received, shutting down`)
      server.close(() => process.exit(0))
      setTimeout(() => process.exit(0), 8000).unref()
    })
  }
}

module.exports = app
