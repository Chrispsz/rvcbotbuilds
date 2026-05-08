// ═══════════════════════════════════════════════════════════════════
// 🤖 RVCArise BOT v34.0 (PRODUCTION)
// Changelog v33→v34:
//   - FIX CRITICAL: MarkdownV2 escaping — \- and \. in JS strings
//     become - and . (backslash eaten by JS), but Telegram requires
//     \- and \. in MarkdownV2. All strings now use \\- and \\. etc.
//   - FIX: telegramApiCall now checks for ok:false and logs errors
//   - FIX: Added MarkdownV2 fallback — if parsing fails, retries as
//     plain text so the bot ALWAYS responds
//   - FIX: Rate limit message had unescaped . (also failed silently)
// ═══════════════════════════════════════════════════════════════════

const TTL_PHONE = 604800;   // 7 dias
const TTL_YOUTUBE = 1800;   // 30 min
const TTL_RATELIMIT = 5;    // 5s entre comandos (anti-spam leve)
const FETCH_TIMEOUT = 12000; // 12s timeout
const MAX_QUERY_LEN = 80;

// ═══════════════════════════════════════════════════════════════════
// 🚀 ENTRY POINT (ES Module - padrão Cloudflare Workers)
// ═══════════════════════════════════════════════════════════════════

export default {
  async fetch(request, env, ctx) {
    // Health check
    if (request.method === 'GET') {
      const status = {
        bot: 'RVCArise Bot Online',
        configured: !!(env.TG_TOKEN && env.ADMIN_ID && env.GITHUB_REPO),
        missing: [
          !env.TG_TOKEN && 'TG_TOKEN',
          !env.ADMIN_ID && 'ADMIN_ID',
          !env.GITHUB_REPO && 'GITHUB_REPO',
        ].filter(Boolean),
      };
      return new Response(JSON.stringify(status, null, 2), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (request.method === 'POST') {
      return handleTelegramWebhook(request, env, ctx);
    }

    return new Response('Method Not Allowed', { status: 405 });
  },

  async scheduled(event, env, ctx) {
    // KV gerencia TTL automaticamente
  },
};

// ═══════════════════════════════════════════════════════════════════
// 📨 TELEGRAM WEBHOOK
// ═══════════════════════════════════════════════════════════════════

async function handleTelegramWebhook(request, env, ctx) {
  const TELEGRAM_API = `https://api.telegram.org/bot${env.TG_TOKEN}`;

  try {
    const update = await request.json();
    if (!update.message?.text) return new Response('OK');

    const chatId = update.message.chat.id;
    const userId = update.message.from.id;
    const text = update.message.text.trim();

    if (!text.startsWith('!')) return new Response('OK');

    const command = text.split(' ')[0].toLowerCase();
    const args = text.slice(command.length).trim();

    const ctxObj = { chatId, userId, env, TELEGRAM_API, ctx };

    // Rate limiting (leve — só pra evitar flood)
    if (!(await checkRateLimit(env, userId))) {
      await sendMessage(ctxObj, '⏳ Aguarde uns segundos\\.\\.\\.');
      return new Response('OK');
    }

    switch (command) {
      case '!help':
      case '!comandos':
      case '!start':
        await handleHelp(ctxObj);
        break;

      case '!d':
        if (args.length >= 2) {
          const sanitized = sanitizeInput(args);
          if (sanitized) {
            await handlePhoneSearch(ctxObj, sanitized);
          } else {
            await sendMessage(ctxObj, '⚠️ Query inválida\\.');
          }
        } else {
          await sendMessage(ctxObj, '⚠️ Digite o nome do celular\\. Ex: `!d galaxy s24`');
        }
        break;

      case '!youtube':
      case '!rvcbot':
        await handleYoutubeCommand(ctxObj);
        break;

      case '!debug':
        if (userId === Number(env.ADMIN_ID) && args.length >= 2) {
          await handleDebug(ctxObj, sanitizeInput(args));
        }
        break;

      case '!resetcache':
        if (userId === Number(env.ADMIN_ID)) {
          await handleResetCache(ctxObj, args);
        } else {
          await sendMessage(ctxObj, '⛔ Sem permissão\\.');
        }
        break;

      case '!ping':
        if (userId === Number(env.ADMIN_ID)) {
          const start = Date.now();
          await sendMessage(ctxObj, '🏓 Pong\\!');
          const latency = Date.now() - start;
          console.log(`[RVCArise] Ping: ${latency}ms`);
        }
        break;
    }

    // Libera rate limit após comando completar
    await clearRateLimit(env, userId);

    return new Response('OK');
  } catch (error) {
    logError('Webhook error', error);
    return new Response('Error', { status: 500 });
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🛡️ RATE LIMITING (leve, só anti-flood)
// ═══════════════════════════════════════════════════════════════════

async function checkRateLimit(env, userId) {
  if (!env.RVC_BOT_KV) return true;
  const key = `ratelimit:${userId}`;
  const existing = await env.RVC_BOT_KV.get(key);
  if (existing) return false;
  await env.RVC_BOT_KV.put(key, '1', { expirationTtl: TTL_RATELIMIT });
  return true;
}

// Limpa rate limit ao completar comando (pra não travar o próximo)
async function clearRateLimit(env, userId) {
  if (!env.RVC_BOT_KV) return;
  const key = `ratelimit:${userId}`;
  await env.RVC_BOT_KV.delete(key);
}

// ═══════════════════════════════════════════════════════════════════
// 🧹 AUTO-LIMPEZA (via waitUntil)
// ═══════════════════════════════════════════════════════════════════

function deleteMessageDelayed(ctxObj, msgId, delaySeconds) {
  if (!msgId || !ctxObj?.ctx) return;
  ctxObj.ctx.waitUntil(
    new Promise(resolve => {
      setTimeout(async () => {
        try { await deleteMessage(ctxObj, msgId); } catch (e) { /* silencioso */ }
        resolve();
      }, delaySeconds * 1000);
    })
  );
}

// ═══════════════════════════════════════════════════════════════════
// 🛡️ INPUT SANITIZATION
// ═══════════════════════════════════════════════════════════════════

function sanitizeInput(query) {
  if (!query || typeof query !== 'string') return null;
  let clean = query
    .replace(/[<>"'\\{}|$`;]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, MAX_QUERY_LEN);
  return clean.length >= 2 ? clean : null;
}

// ═══════════════════════════════════════════════════════════════════
// 📋 MARKDOWN ESCAPING (Telegram MarkdownV2)
// ═══════════════════════════════════════════════════════════════════

function escapeMd(text) {
  if (!text) return '';
  return text.replace(/([_*\[\]()~`>#+\-=|{}.!])/g, '\\$1');
}

// ═══════════════════════════════════════════════════════════════════
// ⏱️ FETCH COM TIMEOUT
// ═══════════════════════════════════════════════════════════════════

async function fetchWithTimeout(url, options = {}, timeoutMs = FETCH_TIMEOUT) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const resp = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(timeout);
    return resp;
  } catch (e) {
    clearTimeout(timeout);
    if (e.name === 'AbortError') {
      throw new Error(`Fetch timeout: ${url.slice(0, 60)}`);
    }
    throw e;
  }
}

// ═══════════════════════════════════════════════════════════════════
// 📋 HELP
// ═══════════════════════════════════════════════════════════════════

async function handleHelp(ctx) {
  const msg = '🤖 *RVCArise Bot*\n\n' +
    '📱 `!d <nome>` \\- Especificações\n' +
    '📦 `!youtube` \\- Última versão\n' +
    '🧹 `!resetcache` \\- Limpar dados\n' +
    '🏓 `!ping` \\- Status do bot';
  await sendMessage(ctx, msg);
}

// ═══════════════════════════════════════════════════════════════════
// 🛡️ HEADERS & UTILS
// ═══════════════════════════════════════════════════════════════════

const USER_AGENTS = [
  'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
];

function getHeaders(attempt = 0) {
  const ua = USER_AGENTS[attempt % USER_AGENTS.length];
  return {
    'User-Agent': ua,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept-Encoding': 'gzip, deflate, br',
    'Referer': 'https://www.google.com/',
    'Cache-Control': 'no-cache',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };
}

function isBlocked(html, status) {
  if (!html || status >= 400) return true;
  if (html.length < 1000) return true;
  const blocks = [
    'Attention Required', 'Access Denied', 'Just a moment',
    'Enable JavaScript', 'cf-browser', 'error 1010',
    'Cloudflare', 'Please Wait',
  ];
  return blocks.some(b => html.includes(b));
}

// ═══════════════════════════════════════════════════════════════════
// 🧠 ALGORITMO DE RELEVÂNCIA (melhorado)
// ═══════════════════════════════════════════════════════════════════

function calculateRelevance(candidateName, queryWords, originalQuery) {
  const cWords = candidateName.toLowerCase().replace(/-/g, ' ').split(/\s+/).filter(w => w.length > 1);
  let score = 0;
  let matchedWords = 0;

  if (candidateName.toLowerCase() === originalQuery.toLowerCase()) {
    score += 500;
  }

  if (candidateName.toLowerCase().startsWith(originalQuery.toLowerCase())) {
    score += 300;
  }

  queryWords.forEach(q => {
    const qLower = q.toLowerCase();
    if (candidateName.toLowerCase().includes(qLower)) {
      if (cWords.some(cw => cw === qLower)) {
        score += 120;
      } else {
        score += 80;
      }
      matchedWords++;
    }
  });

  if (matchedWords === 0) return 0;

  const coverage = matchedWords / queryWords.length;
  score += Math.floor(coverage * 150);

  const modifiers = [
    'plus', 'pro', 'max', 'ultra', 'lite', 'mini',
    'note', 'edge', 'fe', 'neo', 'prime', 'turbo',
    'power', '5g', '4g',
  ];
  modifiers.forEach(mod => {
    if (cWords.includes(mod) && !queryWords.includes(mod)) {
      score -= 200;
    }
  });

  const lengthDiff = Math.abs(cWords.length - queryWords.length);
  score -= lengthDiff * 15;

  return score;
}

// ═══════════════════════════════════════════════════════════════════
// 🔍 GSMArena: BUSCA
// ═══════════════════════════════════════════════════════════════════

async function fetchGSMArena(query) {
  const qWords = query.toLowerCase().split(/\s+/).filter(w => w.length > 1);

  const searchUrls = [
    {
      label: 'Desktop',
      url: `https://www.gsmarena.com/results.php3?sQuickSearch=yes&sName=${encodeURIComponent(query)}`,
    },
    {
      label: 'Mobile',
      url: `https://m.gsmarena.com/res.php3?sSearch=${encodeURIComponent(query)}`,
    },
  ];

  let debugInfo = { attempts: [], finalUrl: null, candidates: [] };

  for (const { label, url: searchUrl } of searchUrls) {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const resp = await fetchWithTimeout(searchUrl, {
          headers: getHeaders(attempt),
          redirect: 'follow',
        });
        const finalUrl = resp.url;
        const html = await resp.text();

        debugInfo.attempts.push({
          url: label,
          status: resp.status,
          htmlLen: html.length,
          blocked: isBlocked(html, resp.status),
          attempt: attempt + 1,
        });

        if (isBlocked(html, resp.status)) continue;
        debugInfo.finalUrl = finalUrl;

        if (
          html.includes('No phone found') ||
          html.includes('0 results found') ||
          html.includes('did not match')
        ) {
          return { type: 'empty', debug: debugInfo };
        }

        if (
          !finalUrl.includes('results.php3') &&
          !finalUrl.includes('res.php3')
        ) {
          if (html.includes('specs-phone-name-title') || html.includes('specs-list')) {
            return { type: 'direct', url: finalUrl, html, debug: debugInfo };
          }
        }

        const candidates = extractCandidatesSmart(html, qWords, query);
        debugInfo.candidates = candidates.map(c => `${c.name} (Score:${c.score})`);

        if (candidates.length > 0) {
          return { type: 'list', candidates, debug: debugInfo };
        }
      } catch (e) {
        debugInfo.attempts.push({ url: label, error: e.message, attempt: attempt + 1 });
      }
    }
  }

  return { type: 'failed', debug: debugInfo };
}

function extractCandidatesSmart(html, queryWords, originalQuery) {
  const candidates = [];
  const seen = new Set();

  const regex1 = /<a\s+href="([a-z0-9_-]+\.php)"[^>]*>([\s\S]*?)<\/a>/gi;
  const regex2 = /<a\s+[^>]*href="([a-z0-9_-]+\.php)"[^>]*data-src[^>]*>([\s\S]*?)<\/a>/gi;

  for (const regex of [regex1, regex2]) {
    let match;
    while ((match = regex.exec(html)) !== null) {
      const slug = match[1];
      const rawName = match[2];
      let cleanName = rawName
        .replace(/<br\s*\/?>/gi, ' ')
        .replace(/<[^>]+>/g, '')
        .replace(/\s+/g, ' ')
        .trim();

      if (!isValidPhone(slug, cleanName)) continue;
      if (seen.has(slug)) continue;
      seen.add(slug);

      const score = calculateRelevance(cleanName, queryWords, originalQuery);
      if (score <= 0 && queryWords.length > 0) continue;

      candidates.push({
        url: `https://www.gsmarena.com/${slug}`,
        name: cleanName,
        score,
      });
    }
  }

  candidates.sort((a, b) => b.score - a.score);
  return candidates.slice(0, 10);
}

function isValidPhone(slug, name) {
  if (!slug || slug.length < 5) return false;
  if (!slug.includes('-') && !slug.includes('_')) return false;
  if (slug.includes('-phones-') || slug.includes('-watch-') || slug.includes('-tablet-')) return false;
  if (!/-\d+\.php$/.test(slug)) return false;
  if (/^(compare|related|news|review|pictures|s\.php|makers|network|search|faq|contact)/.test(slug)) return false;
  if (name && name.length < 3) return false;
  return true;
}

function selectBest(candidates, query) {
  return candidates[0];
}

// ═══════════════════════════════════════════════════════════════════
// 📱 BUSCA DE CELULAR
// ═══════════════════════════════════════════════════════════════════

async function handlePhoneSearch(ctxObj, query) {
  const KV = ctxObj.env.RVC_BOT_KV;
  const cacheKey = `phone:${query.toLowerCase().replace(/\s+/g, '-')}`;

  // Cache check
  if (KV) {
    const cached = await KV.get(cacheKey, 'json');
    if (cached) {
      await sendResult(ctxObj, cached.specs, cached.url);
      return;
    }
  }

  const loadMsg = await sendMessage(ctxObj, '🔍 Buscando\\.\\.\\.');
  const loadId = loadMsg?.result?.message_id;

  try {
    const result = await fetchGSMArena(query);

    if (result.type === 'empty') {
      const errId = (await editMessage(ctxObj, loadId, '❌ Aparelho não encontrado: *' + escapeMd(query) + '*\n_Tente abreviar ou verificar o nome\\._'))?.result?.message_id;
      if (errId) deleteMessageDelayed(ctxObj, errId, 10);
      return;
    }

    if (result.type === 'failed') {
      const errId = (await editMessage(ctxObj, loadId, '❌ Erro ao acessar GSMArena\\. Tente novamente em alguns minutos\\.'))?.result?.message_id;
      if (errId) deleteMessageDelayed(ctxObj, errId, 10);
      return;
    }

    let phoneUrl, html;

    if (result.type === 'direct') {
      phoneUrl = result.url;
      html = result.html;
    } else {
      const best = selectBest(result.candidates, query);
      phoneUrl = best.url;

      html = await fetchPhonePage(phoneUrl);
      if (!html) {
        const errId = (await editMessage(ctxObj, loadId, '❌ Erro ao carregar página do aparelho\\.'))?.result?.message_id;
        if (errId) deleteMessageDelayed(ctxObj, errId, 10);
        return;
      }
    }

    const specs = parseSpecs(html, phoneUrl);

    if (!specs.name) {
      const errId = (await editMessage(ctxObj, loadId, '❌ Dados indisponíveis\\.'))?.result?.message_id;
      if (errId) deleteMessageDelayed(ctxObj, errId, 10);
      return;
    }

    // Salvar no cache
    if (KV) {
      await KV.put(cacheKey, JSON.stringify({ specs, url: phoneUrl }), {
        expirationTtl: TTL_PHONE,
      });
    }

    if (loadId) await deleteMessage(ctxObj, loadId);
    await sendResult(ctxObj, specs, phoneUrl);
  } catch (error) {
    logError('PhoneSearch error', error);
    const errId = (await editMessage(ctxObj, loadId, '❌ Erro interno\\. Tente novamente\\.'))?.result?.message_id;
    if (errId) deleteMessageDelayed(ctxObj, errId, 10);
  }
}

async function fetchPhonePage(url) {
  for (let i = 0; i < 3; i++) {
    try {
      const resp = await fetchWithTimeout(url, {
        headers: getHeaders(i),
        redirect: 'follow',
      });
      const html = await resp.text();
      if (!isBlocked(html, resp.status)) return html;
    } catch (e) {
      logError('fetchPhonePage attempt', e);
    }
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════════
// 📊 PARSER & TRADUÇÃO (mais resiliente)
// ═══════════════════════════════════════════════════════════════════

function parseSpecs(html, url) {
  const specs = {
    name: null, image: null, released: null, body: null,
    display: null, chipset: null, memory: null, os: null,
    camera: null, selfie: null, video: null,
    battery: null, charging: null, nfc: null, jack: null,
  };

  const clean = s =>
    s
      ? s
          .replace(/<[^>]+>/g, '')
          .replace(/&nbsp;/g, ' ')
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&#039;/g, "'")
          .replace(/&quot;/g, '"')
          .replace(/\s+/g, ' ')
          .trim()
      : null;

  const getSpec = key => {
    const m = html.match(new RegExp(`data-spec="${key}"[^>]*>([\\s\\S]*?)<\\/`, 'i'));
    return m ? clean(m[1]) : null;
  };

  const getRow = label => {
    const patterns = [
      new RegExp(`<td[^>]*>\\s*<a[^>]*>${label}</a>\\s*</td>\\s*<td[^>]*class="nfo"[^>]*>([\\s\\S]*?)</td>`, 'i'),
      new RegExp(`<td[^>]*>\\s*${label}\\s*</td>\\s*<td[^>]*class="nfo"[^>]*>([\\s\\S]*?)</td>`, 'i'),
      new RegExp(`>${label}</[^>]+>\\s*</td>\\s*<td[^>]*>([\\s\\S]*?)</td>`, 'i'),
    ];
    for (const p of patterns) {
      const m = html.match(p);
      if (m) return clean(m[1]);
    }
    return null;
  };

  specs.name =
    html.match(/<h1[^>]*class="specs-phone-name-title"[^>]*>([^<]+)/i)?.[1]?.trim() ||
    getSpec('modelname') ||
    html.match(/<span[^>]*class="specs-phone-name-title"[^>]*>([^<]+)/i)?.[1]?.trim() ||
    html.match(/<title>([^<|]+)/i)?.[1]?.replace(/- Full phone specifications/gi, '').trim();

  specs.image =
    html.match(/(https:\/\/fdn\d?\.gsmarena\.com\/vv\/bigpic\/[a-zA-Z0-9_-]+\.jpg)/i)?.[1] ||
    html.match(/(https:\/\/fdn\d?\.gsmarena\.com\/vv\/bigpic\/[a-zA-Z0-9_-]+\.png)/i)?.[1] ||
    html.match(/<meta property="og:image" content="([^"]+)"/i)?.[1];

  if (specs.image?.includes('url=')) {
    const m = specs.image.match(/url=([^&]+)/);
    if (m) specs.image = decodeURIComponent(m[1]);
  }

  specs.released = getSpec('released-hl') || getRow('Announced');
  specs.body = getSpec('body-hl');

  const screenSize = getSpec('displaysize');
  const screenRes = getSpec('displayresolution');
  const screenType = getSpec('displaytype');
  specs.display = [screenSize, screenRes, screenType].filter(Boolean).join(' • ');

  specs.chipset = getSpec('chipset') || getRow('Chipset');
  specs.memory = getSpec('internalmemory') || getRow('Internal');
  specs.os = getSpec('os') || getRow('OS');

  specs.camera =
    getSpec('cam1modules') ||
    getRow('Quad') || getRow('Triple') || getRow('Dual') || getRow('Single');
  specs.selfie = getSpec('cam2modules');
  specs.video = getSpec('cam1video') || getRow('Video');

  specs.battery = getSpec('batdescription1') || html.match(/(\d{3,5})\s*mAh/i)?.[0];
  specs.charging = getRow('Charging') || getSpec('batdescription2');

  specs.nfc = getSpec('nfc') || getRow('NFC');
  specs.jack = getRow('3.5mm jack');

  return specs;
}

function formatSpecs(s, url) {
  const tr = text => {
    if (!text) return '';
    let t = text
      .replace(/non-removable/gi, 'fixa')
      .replace(/removable/gi, 'removível')
      .replace(/Li-Po|Li-Ion/gi, '')
      .replace(/upgradable to/gi, '→')
      .replace(/inches/gi, 'pol')
      .replace(/pixels/gi, 'px')
      .replace(/Released/gi, 'Lançamento')
      .replace(/thickness/gi, 'espessura')
      .replace(/weight/gi, 'peso')
      .replace(/glass front/gi, 'vidro frontal')
      .replace(/glass back/gi, 'vidro traseiro')
      .replace(/aluminum frame/gi, 'estrutura de alumínio')
      .replace(/plastic back/gi, 'traseira plástica')
      .replace(/(\d+W)( wired)/i, '$1 \\(Cabo\\)')
      .replace(/(\d+W)( reverse wired)/i, '$1 Reverso')
      .replace(/wireless/gi, 'sem fio')
      .replace(/January/gi, 'Janeiro')
      .replace(/February/gi, 'Fevereiro')
      .replace(/March/gi, 'Março')
      .replace(/April/gi, 'Abril')
      .replace(/May/gi, 'Maio')
      .replace(/June/gi, 'Junho')
      .replace(/July/gi, 'Julho')
      .replace(/August/gi, 'Agosto')
      .replace(/September/gi, 'Setembro')
      .replace(/October/gi, 'Outubro')
      .replace(/November/gi, 'Novembro')
      .replace(/December/gi, 'Dezembro')
      .replace(/\s+/g, ' ')
      .trim();
    return t;
  };

  let displayName = s.name
    .replace(/ - Full phone specifications/g, '')
    .replace(/ Full phone specifications/g, '')
    .trim();
  if (displayName.endsWith(',')) displayName = displayName.slice(0, -1).trim();

  let msg = '📱 *' + escapeMd(displayName) + '*\n\n';

  if (s.released) msg += '🗓️ ' + tr(escapeMd(s.released)) + '\n';
  if (s.body) msg += '⚖️ ' + tr(escapeMd(s.body)) + '\n';

  if (s.display) msg += '\n🖥️ *Tela*\n' + tr(escapeMd(s.display)) + '\n';

  msg += '\n🧠 *Hardware*\n';
  if (s.chipset) msg += '• CPU: ' + escapeMd(s.chipset) + '\n';
  if (s.memory) msg += '• Memória: ' + escapeMd(s.memory) + '\n';
  if (s.os) msg += '• Sistema: ' + tr(escapeMd(s.os)) + '\n';

  if (s.camera || s.selfie) {
    msg += '\n📸 *Câmeras*\n';
    if (s.camera) msg += '• Traseira: ' + tr(escapeMd(s.camera)) + '\n';
    if (s.video) msg += '• Vídeo: ' + escapeMd(s.video) + '\n';
    if (s.selfie) msg += '• Frontal: ' + tr(escapeMd(s.selfie)) + '\n';
  }

  const extras = [];
  if (s.nfc?.toLowerCase().includes('yes')) extras.push('NFC ✅');
  if (s.jack?.toLowerCase().includes('yes')) extras.push('P2 ✅');
  if (extras.length) msg += '\n📡 ' + extras.join(' • ') + '\n';

  if (s.battery) msg += '\n🔋 *Bateria:* ' + tr(escapeMd(s.battery)) + '\n';
  if (s.charging) msg += '⚡ ' + tr(escapeMd(s.charging)) + '\n';

  msg += '\n🔗 [Ficha completa](' + url + ')';

  if (msg.length > 4000) {
    msg = msg.slice(0, 3990) + '\n\\.\\.\\.';
  }

  return msg;
}

async function sendResult(ctxObj, specs, url) {
  const msg = formatSpecs(specs, url);

  if (specs.image) {
    const result = await sendPhoto(ctxObj, specs.image, msg);
    if (!result?.ok) {
      await sendMessage(ctxObj, msg, { disable_web_page_preview: true });
    }
  } else {
    await sendMessage(ctxObj, msg, { disable_web_page_preview: true });
  }
}

// ═══════════════════════════════════════════════════════════════════
// 🔴 YOUTUBE/RVCBOT
// ═══════════════════════════════════════════════════════════════════

async function handleYoutubeCommand(ctxObj) {
  const KV = ctxObj.env.RVC_BOT_KV;

  // Cache check
  if (KV) {
    const cached = await KV.get('release:latest', 'json');
    if (cached) {
      await sendMessage(ctxObj, formatRelease(cached), { disable_web_page_preview: true });
      return;
    }
  }

  const loadMsg = await sendMessage(ctxObj, '🔄 Buscando\\.\\.\\.');
  const loadId = loadMsg?.result?.message_id;

  try {
    const headers = {
      'User-Agent': 'RVCAriseBot',
      'Accept': 'application/vnd.github.v3+json',
    };

    if (ctxObj.env.GITHUB_TOKEN) {
      headers['Authorization'] = `token ${ctxObj.env.GITHUB_TOKEN}`;
    }

    const resp = await fetchWithTimeout(
      `https://api.github.com/repos/${ctxObj.env.GITHUB_REPO}/releases`,
      { headers }
    );

    if (!resp.ok) {
      let errMsg = '❌ GitHub erro: ' + resp.status;
      if (resp.status === 403) errMsg = '⚠️ Erro 403: Token necessário ou rate limit\\.';
      if (resp.status === 404) errMsg = '⚠️ Repo não encontrado\\. Verifique GITHUB\\_REPO\\.';
      const errId = (await editMessage(ctxObj, loadId, errMsg))?.result?.message_id;
      if (errId) deleteMessageDelayed(ctxObj, errId, 10);
      return;
    }

    const data = await resp.json();

    if (!Array.isArray(data) || data.length === 0) {
      const errId = (await editMessage(ctxObj, loadId, '❌ Nenhuma release encontrada\\.'))?.result?.message_id;
      if (errId) deleteMessageDelayed(ctxObj, errId, 10);
      return;
    }

    const release = data.find(r => !r.prerelease) || data[0];

    // Salvar no cache
    if (KV) {
      await KV.put('release:latest', JSON.stringify(release), {
        expirationTtl: TTL_YOUTUBE,
      });
    }

    if (loadId) await deleteMessage(ctxObj, loadId);
    await sendMessage(ctxObj, formatRelease(release), { disable_web_page_preview: true });
  } catch (e) {
    logError('YoutubeCommand error', e);
    const errId = (await editMessage(ctxObj, loadId, '❌ Erro ao buscar releases\\.'))?.result?.message_id;
    if (errId) deleteMessageDelayed(ctxObj, errId, 10);
  }
}

// Converte GitHub Markdown → Telegram MarkdownV2
// Preserva links [text](url), escapa resto
function githubMdToTelegram(text) {
  if (!text) return '';
  // Proteger links: [text](url) → placeholder inconfundível
  const links = [];
  let result = text.replace(/\[([^\]]*)\]\(([^)]+)\)/g, (match, linkText, url) => {
    links.push({ text: linkText, url });
    return '\x00LINK' + (links.length - 1) + '\x00';
  });
  // Escapar caracteres MarkdownV2 no resto
  result = result.replace(/([_*\[\]()~`>#+\-=|{}.!])/g, '\\$1');
  // Restaurar links com escape no texto do link
  result = result.replace(/\x00LINK(\d+)\x00/g, (_, i) => {
    const link = links[parseInt(i)];
    const escapedText = link.text.replace(/([_*\[\]()~`>#+\-=|{}.!])/g, '\\$1');
    return '[' + escapedText + '](' + link.url + ')';
  });
  return result;
}

function formatRelease(r) {
  const date = new Date(r.published_at).toLocaleDateString('pt-BR');
  const body = (r.body || '')
    .replace(/TG_MSG_ID:.*\n?/g, '')
    .replace(/---/g, '')
    .trim() || '_Sem descrição_';

  let downloads = '';
  if (r.assets?.length) {
    const apks = r.assets.filter(a => a.name.endsWith('.apk'));
    const zips = r.assets.filter(a => a.name.endsWith('.zip'));
    const others = r.assets.filter(a => !a.name.endsWith('.apk') && !a.name.endsWith('.zip'));

    if (apks.length) {
      downloads += '📱 *APKs:*\n';
      apks.forEach(a => {
        const size = (a.size / 1024 / 1024).toFixed(1);
        downloads += '• [' + escapeMd(a.name) + '](' + a.browser_download_url + ') _(' + size + 'MB)_\n';
      });
    }
    if (zips.length) {
      downloads += '🗜️ *Módulos:*\n';
      zips.forEach(a => {
        const size = (a.size / 1024 / 1024).toFixed(1);
        downloads += '• [' + escapeMd(a.name) + '](' + a.browser_download_url + ') _(' + size + 'MB)_\n';
      });
    }
    others.forEach(a => {
      const size = (a.size / 1024 / 1024).toFixed(1);
      downloads += '📦 [' + escapeMd(a.name) + '](' + a.browser_download_url + ') _(' + size + 'MB)_\n';
    });
  }

  let msg = '📦 *RVCArise \\- Atualização*\n\n';
  msg += '🔖 *Versão:* `' + escapeMd(r.tag_name) + '`\n';
  msg += '📅 *Data:* ' + escapeMd(date) + '\n';
  if (body && body !== '_Sem descrição_') msg += '\n📝 *Changelog:*\n' + githubMdToTelegram(body) + '\n';
  msg += '\n⬇️ *Downloads:*\n' + (downloads || '_Nenhum arquivo_');

  if (msg.length > 4000) {
    msg = msg.slice(0, 3990) + '\n\\.\\.\\.';
  }

  return msg;
}

// ═══════════════════════════════════════════════════════════════════
// 🐛 DEBUG
// ═══════════════════════════════════════════════════════════════════

async function handleDebug(ctxObj, query) {
  await sendMessage(ctxObj, '🔍 Debug: *' + escapeMd(query) + '*\nAguarde\\.\\.\\.');
  const result = await fetchGSMArena(query);
  const d = result.debug;

  let msg = '🐛 *DEBUG: ' + escapeMd(query) + '*\n\n';
  msg += '🔄 *Tentativas:*\n';
  for (const a of d.attempts) {
    if (a.error) msg += '• ❌ ' + escapeMd(a.error) + '\n';
    else msg += '• ' + escapeMd(a.url) + ' \\#' + (a.attempt || '?') + ': ' + (a.blocked ? '🚫 Bloqueado' : '✅ OK') + ' \\(' + (a.htmlLen || 0) + ' chars\\)\n';
  }
  msg += '\n📊 *Resultado:* ' + escapeMd(result.type) + '\n';
  if (d.candidates.length > 0) {
    msg += '\n📋 *Top Candidatos:*\n';
    d.candidates.slice(0, 5).forEach((c, i) => {
      msg += (i + 1) + '\\. ' + escapeMd(c) + '\n';
    });
  }
  await sendMessage(ctxObj, msg.slice(0, 4000));
}

// ═══════════════════════════════════════════════════════════════════
// 🧹 CACHE & RESET
// ═══════════════════════════════════════════════════════════════════

async function handleResetCache(ctxObj, query) {
  const KV = ctxObj.env.RVC_BOT_KV;
  if (!KV) {
    await sendMessage(ctxObj, '❌ KV não configurado\\.');
    return;
  }

  let msg = '';
  let deleteAfter = 0;

  if (!query) {
    const list = await KV.list();
    await Promise.all(list.keys.map(k => KV.delete(k.name)));
    msg = '✅ ' + list.keys.length + ' itens removidos\\.';
    deleteAfter = 5;
  } else if (query === 'youtube') {
    await KV.delete('release:latest');
    msg = '✅ YouTube cache limpo\\.';
    deleteAfter = 5;
  } else {
    const key = `phone:${query.toLowerCase().replace(/\s+/g, '-')}`;
    await KV.delete(key);
    msg = '✅ Cache removido\\.';
    deleteAfter = 5;
  }

  const res = await sendMessage(ctxObj, msg);
  if (deleteAfter > 0 && res?.result?.message_id) {
    deleteMessageDelayed(ctxObj, res.result.message_id, deleteAfter);
  }
}

// ═══════════════════════════════════════════════════════════════════
// 📨 TELEGRAM API (com retry + fallback + error logging)
// ═══════════════════════════════════════════════════════════════════

async function telegramApiCall(url, body, retries = 2) {
  for (let i = 0; i <= retries; i++) {
    try {
      const resp = await fetchWithTimeout(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await resp.json();

      // Log Telegram API errors (antes eram ignorados silenciosamente)
      if (!data.ok && data.error_code !== 429) {
        logError('Telegram API error', { error_code: data.error_code, description: data.description });
      }

      // Telegram 429 rate limit
      if (data.error_code === 429 && data.parameters?.retry_after) {
        if (i < retries) {
          await new Promise(r => setTimeout(r, data.parameters.retry_after * 1000));
          continue;
        }
      }

      return data;
    } catch (e) {
      if (i === retries) {
        logError('Telegram API call failed', e);
        return { ok: false, error: e.message };
      }
      await new Promise(r => setTimeout(r, Math.pow(2, i) * 500));
    }
  }
}

async function sendMessage(ctx, text, opts = {}) {
  const result = await telegramApiCall(`${ctx.TELEGRAM_API}/sendMessage`, {
    chat_id: ctx.chatId,
    text,
    parse_mode: 'MarkdownV2',
    ...opts,
  });

  // FALLBACK: se MarkdownV2 falhar, envia como texto puro
  if (!result?.ok && result?.description?.includes("can't parse entities")) {
    logError('MarkdownV2 failed, retrying as plain text', { original_error: result.description });
    return telegramApiCall(`${ctx.TELEGRAM_API}/sendMessage`, {
      chat_id: ctx.chatId,
      text: text.replace(/\\([_*\[\]()~`>#+\-=|{}.!])/g, '$1')
                .replace(/[*_~`>#+=|{}!]/g, '')
                .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1'),
      ...opts,
    });
  }

  return result;
}

async function editMessage(ctx, msgId, text, opts = {}) {
  if (!msgId) return sendMessage(ctx, text, opts);

  const result = await telegramApiCall(`${ctx.TELEGRAM_API}/editMessageText`, {
    chat_id: ctx.chatId,
    message_id: msgId,
    text,
    parse_mode: 'MarkdownV2',
    ...opts,
  });

  // FALLBACK: se MarkdownV2 falhar, edita como texto puro
  if (!result?.ok && result?.description?.includes("can't parse entities")) {
    return telegramApiCall(`${ctx.TELEGRAM_API}/editMessageText`, {
      chat_id: ctx.chatId,
      message_id: msgId,
      text: text.replace(/\\([_*\[\]()~`>#+\-=|{}.!])/g, '$1')
                .replace(/[*_~`>#+=|{}!]/g, '')
                .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1'),
      ...opts,
    });
  }

  return result;
}

async function sendPhoto(ctx, photo, caption) {
  const result = await telegramApiCall(`${ctx.TELEGRAM_API}/sendPhoto`, {
    chat_id: ctx.chatId,
    photo,
    caption,
    parse_mode: 'MarkdownV2',
  });

  // FALLBACK: se caption falhar, manda foto sem caption + msg separada
  if (!result?.ok && result?.description?.includes("can't parse entities")) {
    const photoResult = await telegramApiCall(`${ctx.TELEGRAM_API}/sendPhoto`, {
      chat_id: ctx.chatId,
      photo,
    });
    if (photoResult?.ok) {
      return sendMessage(ctx, caption);
    }
  }

  return result;
}

async function deleteMessage(ctx, msgId) {
  return telegramApiCall(`${ctx.TELEGRAM_API}/deleteMessage`, {
    chat_id: ctx.chatId,
    message_id: msgId,
  }, 0);
}

// ═══════════════════════════════════════════════════════════════════
// 📊 LOGGING
// ═══════════════════════════════════════════════════════════════════

function logError(context, error) {
  console.error(`[RVCArise] ${context}:`, typeof error === 'object' ? JSON.stringify(error) : (error?.message || error));
}
