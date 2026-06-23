import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.IO as TLIO
import Text.Blaze.Html5 as H
import Text.Blaze.Html5.Attributes as A
import Text.Blaze.Html.Renderer.Text (renderHtml)

-- | HTML page that accesses webcam, extracts dominant colors,
--   maps them to notes, plays sound and draws Mondrian rectangles.
main :: IO ()
main = TLIO.writeFile "index.html" $ renderHtml page

page :: Html
page = docTypeHtml $ do
    H.head $ do
        H.title "Audio‑Visual Mondrian"
        -- simple style
        style "body{margin:0;overflow:hidden;background:#111;}canvas{display:block;}"
    body $ do
        canvas ! id "viz" ! width "800" ! height "600"
        script $ toHtml (TL.unlines
            [ "const video = document.createElement('video');"
            , "video.autoplay = true;"
            , "navigator.mediaDevices.getUserMedia({video:true}).then(s=>video.srcObject=s);"
            , "const canvas = document.getElementById('viz');"
            , "const ctx = canvas.getContext('2d');"
            , "const audioCtx = new (window.AudioContext||window.webkitAudioContext)();"
            , "function getDominantColors(imgData){"
            , "  const data = imgData.data, cnt = {}; "
            , "  for(let i=0;i<data.length;i+=4){"
            , "    const key = `${data[i]},${data[i+1]},${data[i+2]}`;"
            , "    cnt[key]=(cnt[key]||0)+1;"
            , "  }"
            , "  return Object.entries(cnt).sort((a,b)=>b[1]-a[1]).slice(0,5).map(e=>e[0].split(',').map(Number));"
            , "}"
            , "const scale = ['C','D','E','F','G','A','B'];"
            , "function playNote(freq){"
            , "  const osc = audioCtx.createOscillator();"
            , "  const gain = audioCtx.createGain();"
            , "  osc.type='sine'; osc.frequency.value=freq;"
            , "  osc.connect(gain).connect(audioCtx.destination);"
            , "  gain.gain.setValueAtTime(0, audioCtx.currentTime);"
            , "  gain.gain.linearRampToValueAtTime(0.2, audioCtx.currentTime+0.01);"
            , "  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime+0.3);"
            , "  osc.start(); osc.stop(audioCtx.currentTime+0.3);"
            , "}"
            , "function colorToFreq([r,g,b]){"
            , "  const avg = (r+g+b)/3;"
            , "  const note = scale[Math.floor(avg/255*scale.length) % scale.length];"
            , "  const base = {C:261.6,D:293.7,E:329.6,F:349.2,G:392.0,A:440.0,B:493.9}[note];"
            , "  return base * (1 + (r-128)/256);"
            , "}"
            , "function drawMondrian(cols){"
            , "  ctx.clearRect(0,0,canvas.width,canvas.height);"
            , "  const w = canvas.width, h = canvas.height;"
            , "  const rects = 5;"
            , "  for(let i=0;i<rects;i++){"
            , "    const cw = w * (0.2+Math.random()*0.3);"
            , "    const ch = h * (0.2+Math.random()*0.3);"
            , "    const x = Math.random()* (w-cw);"
            , "    const y = Math.random()* (h-ch);"
            , "    const col = cols[i%cols.length]||[200,200,200];"
            , "    ctx.fillStyle = `rgb(${col[0]},${col[1]},${col[2]})`;"
            , "    ctx.fillRect(x,y,cw,ch);"
            , "    ctx.strokeStyle='black'; ctx.lineWidth=4; ctx.strokeRect(x,y,cw,ch);"
            , "  }"
            , "}"
            , "function tick(){"
            , "  if(video.readyState===video.HAVE_ENOUGH_DATA){"
            , "    const tmp = document.createElement('canvas');"
            , "    tmp.width=video.videoWidth; tmp.height=video.videoHeight;"
            , "    const tctx = tmp.getContext('2d');"
            , "    tctx.drawImage(video,0,0);"
            , "    const img = tctx.getImageData(0,0,tmp.width,tmp.height);"
            , "    const cols = getDominantColors(img);"
            , "    drawMondrian(cols);"
            , "    cols.forEach(c=>playNote(colorToFreq(c)));"
            , "  }"
            , "  requestAnimationFrame(tick);"
            , "}"
            , "video.addEventListener('loadeddata',()=>{requestAnimationFrame(tick);});"
            ]) ) 
    )