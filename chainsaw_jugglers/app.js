const path = require("path")
const express = require("express")

const app = express()
const publicDir = path.join(__dirname, "public")
const port = Number(process.env.PORT) || 8080

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

app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on http://0.0.0.0:${port}`)
})
