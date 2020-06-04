const fetch = require('node-fetch')
const JSDOM = require('jsdom').JSDOM;
const Readability = require('./readability')
const TurndownService = require('turndown')
const turndownService = new TurndownService()
turndownService.remove('img')
turndownService.remove('hr')

turndownService.addRule('strikethrough', {
  filter: ['img', 'hr', 'dt', 'dd', 'span'],
  replacement: function (content) {
    return ''
  }
})

async function extractData (url) {
  let response = await fetch(url)
  let html = await response.text()//.replace(/^.+?\<body/i, '<body')

  var doc = new JSDOM(html);
  let audioURL = doc.window.document.querySelector('.playbutton a[data-audio-src]')
  if (!audioURL) {
    return null
  }
  audioURL = audioURL.getAttribute('data-audio-src')
  let reader = new Readability(doc.window.document);
  let article = reader.parse();
  let image = doc.window.document.querySelector('meta[property="og:image"]')

  return {
    article,
    audioURL,
    imageURL: (image) ? image.getAttribute('content') : null
  }
}


async function crawlDlf(sites) {
  let finalData = []
  for(let url of sites) {
    let response = await fetch(url)
    let html = await response.text()
    let doc = new JSDOM(html);
    let baseUrl = new URL(url).origin
    let audioSiteURLs = [...doc.window.document.querySelectorAll('.article-grid a[href*="hoerspiel"]')].map((e) => {
      return baseUrl + '/' + e.getAttribute('href')
      // let articleUrl = new URL(baseUrl + '/' + e.getAttribute('href'))
      // return `${articleUrl.origin}/${articleUrl.pathname}`
    })
    for (let siteUrl of new Set(audioSiteURLs)) {
      let data = await extractData(siteUrl);
      if (data) {
        let html = data.article.content.replace(/ xmlns\=\"http:\/\/www.w3.org\/1999\/xhtml\"/g, '')
        // let description = data.article.textContent
        let description = turndownService.turndown(html)
        let audioPlay = {
          Title: data.article.title,
          Author: (data.article.byline) ? data.article.byline.replace(/^(Von|Nach dem .+? von|Nach|Hörspiel von)\s+/i, '') : null,
          Description: description.replace('Abonnieren Sie unseren Newsletter!','').trim(),
          Link: siteUrl,
          Excerpt: data.article.excerpt,
          MediaURL: data.audioURL,
          Broadcaster: 'dlf',
          ContentSource: 'html',
          ArticleContent: data.article.content,
          Image: data.imageURL,
          GUID: siteUrl,
        };
        finalData.push(audioPlay)
      }
    }

  }
  console.log(JSON.stringify(finalData, null, '  '))
  // console.log(finalData)
}


crawlDlf([
  'https://www.deutschlandfunkkultur.de/dlf-hoerspiel.3047.de.html',
  'https://www.deutschlandfunkkultur.de/hoerspiel-und-feature-portal-rubrik-hoerspiel.3659.de.html',
  'https://www.deutschlandfunkkultur.de/hoerspiel-und-feature-portal-rubrik-kriminalhoerspiel.3661.de.html'
])
