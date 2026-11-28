// Captures the upstream rendered components at the same logical width as native snapshots.
import { createRequire } from "node:module"
import { mkdir, readFile, writeFile } from "node:fs/promises"
import path from "node:path"

const require = createRequire(import.meta.url)
const { chromium } = require(process.env.PLAYWRIGHT_PATH || "playwright")
const root = new URL("../", import.meta.url)
const samples = JSON.parse(await readFile(new URL("Sources/AIElementsCatalog/Resources/shadcn-catalog.json", root)))
const output = process.argv[2] || ".build/shadcn-audit/web"
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH })
await mkdir(output, { recursive: true })
const queue = samples.filter(item => process.argv.length <= 3 || process.argv.slice(3).includes(item.id))
const measurementsPath = path.join(output, "measurements.json")
const previous = await readFile(measurementsPath, "utf8").catch(() => "[]")
const measurements = new Map(JSON.parse(previous).map(row => [row.id + row.theme, row]))
const failures = []

async function capture(sample, context) {
  const page = await context.newPage()
  try {
    const url = sample.selector || "https://ui.shadcn.com/docs/components/base/" + sample.id
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 75000 })
    let preview
    if (sample.id === "sidebar") {
      preview = page.locator('[data-slot="sidebar-group"]').filter({ has: page.getByText("Projects", { exact: true }) }).first()
    } else if (sample.id === "typography") {
      preview = page.getByRole("heading", { name: "The Joke Tax", exact: true }).first()
    } else if (sample.id === "chart") {
      preview = page.locator('[data-slot="card"]').first()
    } else if (sample.section) {
      preview = page.locator('[id="' + sample.section + '"]').first().locator('xpath=following::div[@data-slot="component-preview"][1]').locator(".preview").first()
    } else {
      preview = page.locator('[data-slot="component-preview"] .preview').first()
    }
    if (sample.id === "message-scroller") preview = preview.locator('[data-slot="message-scroller"]').first()
    // The docs can replace the hydrated preview between discovery and scrolling.
    for (let attempt = 0; ; attempt++) {
      await preview.waitFor({timeout: 18000})
      try {
        await preview.scrollIntoViewIfNeeded()
        break
      } catch (error) {
        if (attempt >= 2 || !String(error).includes("not attached to the DOM")) throw error
      }
    }
    if (sample.id==="avatar") await preview.locator('[data-slot="avatar-image"]').waitFor({timeout:20000})
    if (sample.id === "progress") {
      // The live demo moves from 13% to 66% after hydration. Match the settled sample.
      const settled = preview.locator('[role="progressbar"][aria-valuenow="' + sample.root.value + '"]')
      await settled.waitFor({timeout: 20000})
    }
    const canvas = page.locator("#native-reference-canvas")
    for (const theme of ["light","dark"]) {
      await page.evaluate(t => { document.documentElement.classList.toggle("dark",t==="dark"); document.documentElement.classList.toggle("light",t==="light"); document.documentElement.style.colorScheme=t },theme)
      await preview.evaluate((el,id) => {
        if (id==="chart") Object.assign(el.style,{width:"360px",maxWidth:"360px"})
        if (el.classList.contains("preview") || id === "message-scroller")
          Object.assign(el.style,{width:"360px",maxWidth:"360px",height:id==="message-scroller"?"418px":"auto",minHeight:"0",padding:"0"})
        if (["attachment","bubble","marker","message"].includes(id) && el.firstElementChild) el.firstElementChild.style.paddingBlock="0"
      },sample.id)
      await page.evaluate(() => document.fonts.ready)
      await page.waitForTimeout(sample.id==="chart" ? 2000 : 450)
      await preview.evaluate((el,id) => {
        document.getElementById("native-reference-canvas")?.remove()
        const stage=document.createElement("div")
        stage.id="native-reference-canvas"
        const style=getComputedStyle(el)
        // The docs wrap each demo in a themed container. Preserve its actual computed
        // variables and inherited font when isolating a copy of the mounted DOM.
        for (const property of style) if (property.startsWith("--")) stage.style.setProperty(property,style.getPropertyValue(property))
        Object.assign(stage.style,{position:"fixed",inset:"0 auto auto 0",width:"360px",minHeight:"64px",
          display:"flex",justifyContent:"center",alignItems:"center",overflow:"hidden",zIndex:2147483647,
          fontFamily:style.fontFamily,color:style.color,backgroundColor:"var(--background)"})
        const copy=el.cloneNode(true)
        if (copy.classList.contains("preview")) Object.assign(copy.style,{display:"flex",alignItems:"center",justifyContent:"center",minHeight:"0",padding:"0"})
        if (id==="sidebar") Object.assign(copy.style,{width:"256px",backgroundColor:"var(--sidebar)"})
        if (id==="message-scroller") Object.assign(copy.style,{height:"418px",width:"360px",flex:"none"})
        stage.append(copy)
        document.body.append(stage)
      },sample.id)
      await canvas.locator("img").evaluateAll(imgs=>Promise.all(imgs.map(img=>{ img.loading="eager"; return Promise.race([img.decode().catch(()=>{}),new Promise(resolve=>setTimeout(resolve,1800))]) })))
      const bounds = await canvas.boundingBox()
      if (!bounds || bounds.height < 1) throw new Error("Empty preview")
      await canvas.screenshot({path:path.join(output,sample.id+"-"+theme+".png"),animations:"disabled",timeout:20000})
      const source = url+(sample.section ? "#"+sample.section : "")
      measurements.set(sample.id+theme,{id:sample.id,theme,source,width:bounds.width,height:bounds.height})
    }
  } finally { await page.close() }
}
async function worker() {
  const context = await browser.newContext({viewport:{width:1280,height:1000},deviceScaleFactor:1,reducedMotion:"reduce"})
  // The documented avatar is hosted on GitHub. Use its bundled grayscale copy for
  // that exact image URL so rate limits do not switch the upstream demo to "CN".
  await context.route(/^https:\/\/github\.com\/shadcn\.png(?:[?#].*)?$/, async route => {
    await route.fulfill({contentType:"image/png",body:await readFile(new URL("Sources/AIElements/Resources/Shadcn/shadcn-avatar.png",root))})
  })
  try {
    for (let sample; (sample=queue.shift());) {
      try { await capture(sample,context) }
      catch (error) { failures.push(sample.id); console.error(sample.id,String(error).split("\n")[0]) }
    }
  } finally { await context.close() }
}
async function verifyIndex() {
  const groups=await Promise.all(["base","radix","aria"].map(async base=>{
    const page=await browser.newPage()
    try {
      const prefix="/docs/components/"+base+"/"
      await page.goto(base==="base" ? "https://ui.shadcn.com/docs/components" : "https://ui.shadcn.com"+prefix+"accordion",{waitUntil:"domcontentloaded",timeout:75000})
      const links=page.locator('a[href^="'+prefix+'"]')
      await links.first().waitFor({state:"attached"})
      return await links.evaluateAll((links,prefix)=>links.map(link=>link.getAttribute("href").slice(prefix.length)).filter(slug=>/^[a-z0-9-]+$/.test(slug)),prefix)
    } finally { await page.close() }
  }))
  const live=[...new Set(groups.flat())].sort()
  const catalog=samples.map(example=>example.id).sort()
  if (JSON.stringify(live)!==JSON.stringify(catalog)) throw new Error("Official index differs. Missing: "+live.filter(id=>!catalog.includes(id))+"; removed: "+catalog.filter(id=>!live.includes(id)))

}
try {
  await verifyIndex()
  await Promise.all(Array.from({length:4},worker))
}
finally { await browser.close() }
await writeFile(measurementsPath,JSON.stringify([...measurements.values()].sort((a,b)=>a.id.localeCompare(b.id)||a.theme.localeCompare(b.theme)),null,2)+"\n")
if (failures.length) process.exitCode=1
