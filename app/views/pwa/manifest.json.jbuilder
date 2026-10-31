json.id '/'
json.name t('.name')
json.short_name t('.short_name')
json.description t('.description')
json.lang I18n.locale.to_s
json.icons [
  { src: '/icon-192.png', type: 'image/png', sizes: '192x192' },
  { src: '/icon.png', type: 'image/png', sizes: '512x512' },
  { src: '/icon.png', type: 'image/png', sizes: '512x512', purpose: 'maskable' },
]
json.start_url '/'
json.scope '/'
json.display 'standalone'
json.orientation 'portrait'
json.theme_color '#0b3fae'
json.background_color '#000000'
