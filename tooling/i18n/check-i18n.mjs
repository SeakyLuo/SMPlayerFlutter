import { readFileSync } from 'node:fs'

const localeFiles = [
  'locales/en-US.json',
  'locales/zh-CN.json',
  'locales/fr.json',
  'locales/ru.json',
  'locales/ja.json',
  'locales/de.json',
  'locales/pt-BR.json',
  'locales/es.json',
  'locales/it.json',
  'locales/zh-Hant.json',
  'locales/nl.json',
  'locales/cs.json',
  'locales/uk.json',
  'locales/sv.json',
  'locales/id.json',
]

const dictionaries = new Map(localeFiles.map((file) => [file, readDictionary(file)]))
const source = dictionaries.get('locales/zh-CN.json')
const sourceKeys = Object.keys(source)
const failures = []

for (const [file, dictionary] of dictionaries) {
  const rawSource = readFileSync(file, 'utf8')
  const keys = Object.keys(dictionary)
  const missing = sourceKeys.filter((key) => !(key in dictionary))
  const extra = keys.filter((key) => !(key in source))

  if (missing.length > 0) {
    failures.push(`${file} is missing keys: ${missing.join(', ')}`)
  }

  if (extra.length > 0) {
    failures.push(`${file} has unknown keys: ${extra.join(', ')}`)
  }

  if (/\\u[0-9a-fA-F]{4}/.test(rawSource)) {
    failures.push(`${file} contains escaped unicode text`)
  }

  for (const key of sourceKeys) {
    if (!(key in dictionary)) {
      continue
    }

    if (dictionary[key].length === 0) {
      failures.push(`${file} has empty translation at ${key}`)
    }

    const sourcePlaceholders = getPlaceholders(source[key])
    const targetPlaceholders = getPlaceholders(dictionary[key])
    if (sourcePlaceholders.join('|') !== targetPlaceholders.join('|')) {
      failures.push(`${file} has placeholder mismatch at ${key}: expected ${sourcePlaceholders.join(', ') || 'none'}, got ${targetPlaceholders.join(', ') || 'none'}`)
    }
  }
}

if (failures.length > 0) {
  console.error(failures.join('\n'))
  process.exit(1)
}

console.log(`i18n check passed: ${sourceKeys.length} keys across ${localeFiles.length} locales`)

function readDictionary(file) {
  return JSON.parse(readFileSync(file, 'utf8'))
}

function getPlaceholders(value) {
  return [...value.matchAll(/\{[a-zA-Z][a-zA-Z0-9]*\}/g)].map((match) => match[0]).sort()
}
