import { cp, mkdir, readdir, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const root = new URL('.', import.meta.url).pathname;
const output = join(root, 'dist');
const baseUrl = 'https://curitalk.app';
const email = 'tomatalk.support@gmail.com';
const appleSubscriptions = 'https://apps.apple.com/account/subscriptions';
const appleEula = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[character]);

const copy = {
  ko: {
    nav: { features: '기능', preview: '앱 화면', support: '지원', privacy: '개인정보처리방침', language: 'English' },
    home: {
      title: 'tomatalk — 말하고 싶은 주제로 시작하는 AI 회화',
      description: '관심 있는 주제로 AI와 대화하고, 역할극과 문법 피드백으로 말하기를 이어가는 회화 앱.',
      eyebrow: 'AI 회화 학습 앱 · iOS',
      heading: '내가 고른 주제로,\n오늘도 한 문장.',
      intro: 'tomatalk은 관심 있는 주제로 AI와 대화하고, 상황별 역할극과 문법 피드백으로 연습을 이어가는 앱이에요.',
      download: 'App Store에서 다운로드', coming: '출시 준비 중',
      explore: '앱 살펴보기',
      featureLabel: 'TOMATALK에서 할 수 있는 일',
      featureHeading: '나의 관심사가\n대화 주제가 되요!',
      features: [
        ['01', '관심 주제로 자유 대화', '내가 이야기하고 싶은 주제를 고르고 AI와 대화를 시작해요.', 'lime'],
        ['02', '상황별 역할극', '상황과 역할을 정해 실제 대화처럼 연습해요.', 'lilac'],
        ['03', '문법 피드백', '내가 보낸 문장에서 교정할 부분을 확인해요.', 'blue'],
        ['04', '오늘의 토마토', '짧은 표현을 하나씩 살펴보고, iOS 홈 화면 위젯에서도 이어가요.', 'cream'],
      ],
      previewLabel: 'APP PREVIEW',
      previewHeading: 'tomatalk에서는\n이렇게 대화해요.',
      previewIntro: '선택한 주제로 대화를 시작하고, 피드백을 확인하는 앱 화면을 살펴보세요.',
      previewPending: '실제 앱 화면을 준비하고 있어요.',
      closing: '오늘의 한 문장부터\n시작해 볼까요?',
    },
    support: {
      title: 'tomatalk 고객 지원', description: 'tomatalk 사용과 계정·구독에 관한 도움말과 문의처.',
      eyebrow: 'HELP & SUPPORT', heading: '도움이 필요하신가요?',
      intro: '앱 사용 중 불편한 점이나 의견이 있다면 이메일로 알려주세요.',
      contact: '이메일 문의', emailHint: '문제 상황, 앱 버전, 기기와 iOS 버전을 함께 적어주시면 확인에 도움이 돼요. 비밀번호는 보내지 마세요.',
      faqHeading: '자주 묻는 질문',
      faqs: [
        ['계정을 어떻게 삭제하나요?', '앱의 내 정보 화면 아래쪽에서 계정 삭제를 누르고 안내에 따라 확인하세요. 대화와 학습 기록은 삭제 후 복구되지 않아요. 삭제 작업이 진행 중이면 앱에서 삭제 상태 확인을 눌러 진행 상태를 볼 수 있어요.'],
        ['계정을 삭제하면 Apple 구독도 취소되나요?', `아니요. Apple 구독은 자동으로 취소되지 않아요. 결제가 계속되지 않도록 <a href="${appleSubscriptions}" target="_blank" rel="noopener noreferrer">Apple 구독 관리</a>에서 별도로 취소해 주세요.`],
        ['구매한 구독을 어떻게 복원하나요?', '구독 상품이 제공되는 경우 앱의 내 정보 → 구독 → 더 보기 → 구매 복원에서 복원할 수 있어요. 재가입 후에는 유효한 구독 권한만 복원되며 삭제된 학습 기록은 복구되지 않아요.'],
        ['음성이나 마이크가 작동하지 않아요.', '기기의 tomatalk 마이크 권한과 네트워크 연결을 확인하고 앱을 다시 열어 주세요. 계속 문제가 생기면 기기·iOS 버전과 오류가 발생한 단계를 이메일로 알려주세요.'],
      ],
      legalHeading: '문서', legalText: '개인정보 처리 방식과 Apple 표준 이용약관을 확인할 수 있어요.',
    },
    privacy: {
      title: 'tomatalk 개인정보처리방침', description: 'tomatalk의 개인정보 수집·이용, AI와 음성 처리, 보관 및 삭제 안내.',
      eyebrow: 'PRIVACY', heading: '개인정보처리방침',
      lead: '엑셈플러는 tomatalk 서비스 제공에 필요한 정보를 처리해요. 아래에서 어떤 정보를 왜 사용하고 언제 삭제하는지 설명해요.',
      updated: '최종 수정일: 2026년 11월 3일',
      sections: [
        ['1. 운영 주체 및 문의처', `<p>서비스 운영 주체는 엑셈플러(대표 이현준, 사업자등록번호 496-08-03505)예요. 개인정보 관련 문의는 <a href="mailto:${email}">${email}</a> 또는 010-9626-4585로 연락해 주세요.</p><p>주소: 경기도 화성시 동탄구 동탄감배산로 30, 1627동 406호</p>`],
        ['2. 처리하는 정보와 목적', '<ul><li><strong>계정:</strong> Google·Apple 로그인으로 제공된 식별자, 이메일, 이름·프로필 사진 및 앱 닉네임을 계정 생성과 로그인에 사용해요.</li><li><strong>학습 설정:</strong> 앱 표시 언어와 학습·피드백 언어를 화면 표시와 대화 구성에 사용해요.</li><li><strong>학습 내용:</strong> 선택한 주제, 대화 메시지, 역할극 설정, 음성에서 변환된 텍스트와 문법 피드백을 대화 제공·기록 조회에 사용해요.</li><li><strong>음성:</strong> 사용자가 보내는 음성을 음성 인식에 전달하고, AI 응답 텍스트로 재생용 음성을 생성해요.</li><li><strong>구독:</strong> 구독 상품이 제공되는 경우 Apple 거래 식별자와 상품·유효 기간·상태를 구매 검증과 권한 제공에 사용해요.</li><li><strong>진단:</strong> 요청 시각, 경로, 상태 코드, 요청 식별자와 처리 시간을 오류 진단에 사용해요. 대화 본문과 음성 파일은 일반 API 로그에 기록하지 않아요.</li></ul>'],
        ['3. AI 처리와 외부 서비스', '<p>대화 생성과 문법 피드백에는 입력한 텍스트와 필요한 대화 맥락을, 음성 인식에는 사용자가 보낸 음성을, 음성 합성에는 응답 텍스트를 OpenRouter에 전송해요. OpenRouter는 요청한 모델의 제공업체에 처리를 연결할 수 있어요. 계정 인증과 데이터베이스에는 Supabase를, 소셜 로그인에는 Google 또는 Apple을, 구독 결제에는 Apple을 사용해요.</p><p>대화나 음성에 타인의 개인정보 또는 민감한 정보를 입력하지 않도록 주의해 주세요.</p>'],
        ['4. 보관과 삭제', '<p>계정과 대화·학습 기록은 사용자가 직접 삭제하거나 계정을 삭제할 때까지 보관해요. 내 정보 → 계정 삭제에서 요청하면 앱 접근을 차단하고 프로필, 대화, 학습 기록과 사용자별 저장 데이터를 삭제해요. 외부 시스템 작업이 남은 경우 완료까지 처리 중 상태로 표시해요. 계정 삭제 요청의 처리 상태와 구매 권한 확인에 필요한 최소 기록은 별도로 남아요.</p><p>재생용 생성 음성 캐시는 마지막 생성 후 기본 30일이 지나면 정리하며, 대화 또는 계정 삭제 때도 삭제해요. 음성 파일은 장애 복구 대상에 포함하지 않고 필요하면 저장된 텍스트에서 다시 생성해요. 데이터베이스 백업은 최대 7일 보관한 뒤 만료돼요. 삭제 전 생성된 백업에는 삭제된 정보가 만료 전까지 남을 수 있으며, 백업 복원 시 삭제 요청 기록을 대조해 재삭제해야 해요.</p>'],
        ['5. 이용자의 선택과 요청', `<p>앱에서 계정 삭제를 요청할 수 있고, 대화 목록에서 개별 대화를 삭제할 수 있어요. 개인정보 열람·정정·삭제에 관한 문의는 <a href="mailto:${email}">${email}</a>로 보내 주세요. 계정을 삭제해도 Apple 자동 갱신 구독은 취소되지 않으므로 Apple 구독 관리에서 별도로 취소해야 해요.</p>`],
        ['6. 변경 안내', '<p>처리 방식이 바뀌면 이 페이지의 내용을 갱신하고 변경일을 표시해요.</p>'],
      ],
    },
    footer: { tagline: '말하고 싶은 주제로 시작하는 AI 회화', operator: '운영: 엑셈플러 · 대표 이현준', business: '사업자등록번호 496-08-03505', address: '경기도 화성시 동탄구 동탄감배산로 30, 1627동 406호', eula: 'Apple 표준 이용약관' },
  },
  en: {
    nav: { features: 'Features', preview: 'App preview', support: 'Support', privacy: 'Privacy', language: '한국어' },
    home: {
      title: 'tomatalk — AI conversation practice on your terms',
      description: 'Talk with AI about what interests you, practice real situations, and review grammar feedback.',
      eyebrow: 'AI CONVERSATION APP · iOS',
      heading: 'Start with a topic\nyou care about.',
      intro: 'tomatalk lets you talk with AI about your interests, practice situational roleplays, and review grammar feedback.',
      download: 'Download on the App Store', coming: 'Coming soon', explore: 'Explore the app',
      featureLabel: 'WHAT YOU CAN DO', featureHeading: 'Make today’s interests\ntoday’s practice.',
      features: [
        ['01', 'Talk about your interests', 'Choose a topic and start an open conversation with AI.', 'lime'],
        ['02', 'Practice roleplays', 'Choose a situation and a role to practice a real exchange.', 'lilac'],
        ['03', 'Review grammar feedback', 'See corrections for the sentences you send.', 'blue'],
        ['04', 'Today’s tomato', 'Explore short expressions in the app and on the iOS Home Screen widget.', 'cream'],
      ],
      previewLabel: 'APP PREVIEW', previewHeading: 'See how conversations\nwork in tomatalk.',
      previewIntro: 'Explore how the app lets you start a conversation and review feedback.',
      previewPending: 'Real app screenshots are being prepared.', closing: 'Start with one\nsentence today.',
    },
    support: {
      title: 'tomatalk Support', description: 'Get help with tomatalk, your account, and subscriptions.',
      eyebrow: 'HELP & SUPPORT', heading: 'How can we help?',
      intro: 'Email us if something is not working or you have feedback.',
      contact: 'Email support', emailHint: 'Please include what happened, your app version, device, and iOS version. Do not send your password.',
      faqHeading: 'Frequently asked questions',
      faqs: [
        ['How do I delete my account?', 'In the app, open Profile and tap Delete account near the bottom. Follow the confirmation steps. Conversations and learning history cannot be restored after deletion. If processing is still underway, use Check deletion status in the app.'],
        ['Does deleting my account cancel my Apple subscription?', `No. Apple subscriptions do not cancel automatically. To stop future billing, cancel separately in <a href="${appleSubscriptions}" target="_blank" rel="noopener noreferrer">Apple subscription settings</a>.`],
        ['How do I restore a purchase?', 'If subscriptions are available, open Profile → Subscription → Show more → Restore purchases. After rejoining, only an active subscription can be restored; deleted learning history cannot.'],
        ['My microphone or audio is not working.', 'Check tomatalk’s microphone permission and your connection, then reopen the app. If the issue continues, email us your device and iOS version and the step where it happened.'],
      ],
      legalHeading: 'Documents', legalText: 'Read how we handle data and the standard Apple license agreement.',
    },
    privacy: {
      title: 'tomatalk Privacy Policy', description: 'How tomatalk handles account, conversation, audio, and AI data.',
      eyebrow: 'PRIVACY', heading: 'Privacy Policy',
      lead: 'Exemplar processes information needed to provide tomatalk. This page explains what we use, why we use it, and how it is deleted.',
      updated: 'Last updated November 3, 2026',
      sections: [
        ['1. Operator and contact', `<p>tomatalk is operated by Exemplar (representative: Hyunjun Lee; business registration number: 496-08-03505). For privacy requests, email <a href="mailto:${email}">${email}</a> or call +82 10-9626-4585.</p><p>Address: 30, Dongtangambaesan-ro, Dongtan-gu, Hwaseong-si, Gyeonggi-do, 1627-dong 406-ho, Republic of Korea.</p>`],
        ['2. Information and purposes', '<ul><li><strong>Account:</strong> identifiers, email, name, profile photo supplied through Google or Apple sign-in, and your nickname for account access.</li><li><strong>Preferences:</strong> app display language and learning and feedback languages for the app experience.</li><li><strong>Learning content:</strong> topics, conversation messages, roleplay settings, transcribed speech, and grammar feedback for practice and history.</li><li><strong>Audio:</strong> voice you submit for transcription and AI response text used to generate playback audio.</li><li><strong>Subscriptions:</strong> if offered, Apple transaction identifiers, product, expiration, and status to verify purchases and provide access.</li><li><strong>Diagnostics:</strong> request times, route, status, request identifiers, and timing to investigate errors. Normal API logs do not contain conversation text or audio files.</li></ul>'],
        ['3. AI and external services', '<p>We send text and relevant conversation context to OpenRouter for conversations and grammar feedback, submitted voice for transcription, and response text for speech synthesis. OpenRouter may route requests to the selected model provider. We use Supabase for account authentication and the database, Google or Apple for social sign-in, and Apple for subscription payments.</p><p>Please avoid entering someone else’s personal or sensitive information in a conversation.</p>'],
        ['4. Retention and deletion', '<p>We keep your account, conversations, and learning history until you delete them or your account. When you request account deletion in Profile → Delete account, app access is blocked while your profile, conversations, and user-specific data are removed. If an external step remains, the app shows processing until completion. Minimal records needed to track deletion and verify purchase entitlements remain separately.</p><p>Generated playback audio is normally cleaned up 30 days after its last generation and is deleted when its conversation or account is deleted. Audio files are not included in disaster recovery and may be regenerated from saved text. Database backups expire after at most 7 days. Data deleted after a backup was created may remain in that backup until expiry; after restoration, deletion requests must be checked and reapplied.</p>'],
        ['5. Your choices', `<p>You can delete individual conversations in the app and request account deletion. For access, correction, or deletion requests, email <a href="mailto:${email}">${email}</a>. Deleting your account does not cancel an Apple auto-renewable subscription; cancel separately in Apple subscription settings.</p>`],
        ['6. Changes', '<p>We will update this page and its revision date when our data practices change.</p>'],
      ],
    },
    footer: { tagline: 'AI conversation practice on your terms', operator: 'Operated by Exemplar · Hyunjun Lee', business: 'Business registration no. 496-08-03505', address: '30, Dongtangambaesan-ro, Dongtan-gu, Hwaseong-si, Gyeonggi-do, 1627-dong 406-ho, Republic of Korea', eula: 'Apple standard EULA' },
  },
};

const urls = {
  ko: { home: '/', support: '/support', privacy: '/privacy' },
  en: { home: '/en', support: '/en/support', privacy: '/en/privacy' },
};
const lineBreaks = (value) => escapeHtml(value).replaceAll('\n', '<br>');

function pageShell(locale, page, body) {
  const c = copy[locale];
  const other = locale === 'ko' ? 'en' : 'ko';
  const metadata = c[page];
  const canonical = `${baseUrl}${urls[locale][page]}`;
  const isHome = page === 'home';
  return `<!doctype html>
<html lang="${locale}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#ffffff">
  <title>${escapeHtml(metadata.title)}</title>
  <meta name="description" content="${escapeHtml(metadata.description)}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="tomatalk">
  <meta property="og:title" content="${escapeHtml(metadata.title)}">
  <meta property="og:description" content="${escapeHtml(metadata.description)}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:image" content="${baseUrl}/assets/app-icon.png">
  <meta name="twitter:card" content="summary">
  <link rel="canonical" href="${canonical}">
  <link rel="alternate" hreflang="ko" href="${baseUrl}${urls.ko[page]}">
  <link rel="alternate" hreflang="en" href="${baseUrl}${urls.en[page]}">
  <link rel="icon" href="/assets/app-icon.png" type="image/png">
  <link rel="stylesheet" href="/style.css">
</head>
<body class="${isHome ? 'home-page' : 'document-page'}">
  <a class="skip-link" href="#main">${locale === 'ko' ? '본문으로 이동' : 'Skip to content'}</a>
  <header class="site-header">
    <div class="header-inner">
      <a class="brand" href="${urls[locale].home}" aria-label="tomatalk"><img src="/assets/wordmark.png" alt="" width="170" height="57"></a>
      <nav class="site-nav" aria-label="${locale === 'ko' ? '주 메뉴' : 'Main navigation'}">
        ${isHome ? `<a href="#features">${c.nav.features}</a><a href="#preview">${c.nav.preview}</a>` : `<a href="${urls[locale].home}">${locale === 'ko' ? '홈' : 'Home'}</a>`}
        <a href="${urls[locale].support}" ${page === 'support' ? 'aria-current="page"' : ''}>${c.nav.support}</a>
        <a class="language-link" href="${urls[other][page]}" lang="${other}" hreflang="${other}">${c.nav.language}</a>
      </nav>
    </div>
  </header>
  <main id="main">${body}</main>
  <footer class="site-footer">
    <div class="footer-top">
      <div><a class="footer-brand" href="${urls[locale].home}" aria-label="${locale === 'ko' ? 'tomatalk 홈' : 'tomatalk home'}"><img src="/assets/wordmark.png" alt="" width="220" height="73"></a><p>${c.footer.tagline}</p></div>
      <nav aria-label="${locale === 'ko' ? '하단 메뉴' : 'Footer navigation'}"><a href="${urls[locale].support}">${c.nav.support}</a><a href="${urls[locale].privacy}">${c.nav.privacy}</a><a href="${appleEula}" target="_blank" rel="noopener noreferrer">${c.footer.eula}</a><a href="${urls[other][page]}" lang="${other}" hreflang="${other}">${c.nav.language}</a></nav>
    </div>
    <div class="footer-bottom"><span>${c.footer.operator} · ${c.footer.business}</span><span>${c.footer.address}</span><a href="mailto:${email}">${email}</a></div>
  </footer>
</body>
</html>`;
}

async function screenshotNames(locale) {
  try {
    const names = (await readdir(join(root, 'assets', 'screenshots', locale))).filter((name) => /^screen-[1-3]\.png$/.test(name)).sort();
    return names.length === 3 ? names : [];
  } catch { return []; }
}

function landing(locale, screenshots) {
  const h = copy[locale].home;
  const featureCards = h.features.map(([number, title, description, color]) => `<article class="feature feature-${color}"><span class="feature-number">${number} / 04</span><div><h3>${title}</h3><p>${description}</p></div></article>`).join('');
  const preview = screenshots.length ? `<div class="preview-gallery">${screenshots.map((name, index) => `<figure class="preview-item"><img src="/assets/screenshots/${locale}/${name}" alt="${escapeHtml(locale === 'ko' ? `tomatalk 실제 앱 화면 ${index + 1}` : `Actual tomatalk app screen ${index + 1}`)}" loading="lazy"><figcaption>${escapeHtml(locale === 'ko' ? ['홈에서 시작하기', '대화 이어가기', '학습 피드백 확인'][index] : ['Start from Home', 'Keep the conversation going', 'Review learning feedback'][index])}</figcaption></figure>`).join('')}</div>` : `<div class="preview-pending"><img src="/assets/tomato-basket.png" alt="" width="190" height="178"><p>${h.previewPending}</p></div>`;
  return `<section class="hero section-wrap">
    <div class="hero-copy"><span class="eyebrow">${h.eyebrow}</span><h1>${lineBreaks(h.heading)}</h1><p class="hero-intro">${h.intro}</p><div class="hero-actions"><button type="button" class="download-button" disabled aria-describedby="download-status">${h.download}</button><span id="download-status" class="coming-soon">${h.coming}</span></div><a class="text-link" href="#features">${h.explore}<span aria-hidden="true"> ↘</span></a></div>
    <div class="hero-art" role="img" aria-label="${screenshots.length ? (locale === 'ko' ? 'tomatalk 실제 앱 화면' : 'Actual tomatalk app screen') : (locale === 'ko' ? 'tomatalk 앱 아이콘' : 'tomatalk app icon')}"><div class="hero-petal hero-petal-one"></div><div class="hero-petal hero-petal-two"></div>${screenshots.length ? `<img class="hero-screen" src="/assets/screenshots/${locale}/${screenshots[0]}" alt="" width="300">` : `<div class="hero-icon-wrap"><img src="/assets/app-icon.png" alt="" width="340" height="340"></div>`}<div class="hero-sticker">TALK<br>ABOUT<br>ANYTHING<span>✳</span></div></div>
  </section>
  <section class="feature-section section-wrap" id="features"><div class="section-heading"><span class="eyebrow">${h.featureLabel}</span><h2>${lineBreaks(h.featureHeading)}</h2></div><div class="feature-grid">${featureCards}</div></section>
  <section class="preview-section" id="preview"><div class="section-wrap"><div class="section-heading preview-heading"><div><span class="eyebrow">${h.previewLabel}</span><h2>${lineBreaks(h.previewHeading)}</h2></div><p>${h.previewIntro}</p></div>${preview}</div></section>
  <section class="closing-section section-wrap"><h2>${lineBreaks(h.closing)}</h2><div><button type="button" class="download-button" disabled aria-describedby="closing-download-status">${h.download}</button><span id="closing-download-status" class="coming-soon">${h.coming}</span></div></section>`;
}

function support(locale) {
  const s = copy[locale].support;
  const faq = s.faqs.map(([question, answer]) => `<details class="faq-item"><summary>${question}<span aria-hidden="true">+</span></summary><div class="faq-answer"><p>${answer}</p></div></details>`).join('');
  return `<section class="document-hero section-wrap"><span class="eyebrow">${s.eyebrow}</span><h1>${s.heading}</h1><p>${s.intro}</p></section>
  <section class="support-contact section-wrap"><div class="contact-card"><div><span class="eyebrow">CONTACT</span><h2>${email.replace('@', '@<wbr>')}</h2><p>${s.emailHint}</p></div><a class="pill-link" href="mailto:${email}">${s.contact}<span aria-hidden="true">↗</span></a></div></section>
  <section class="faq-section section-wrap"><h2>${s.faqHeading}</h2><div class="faq-list">${faq}</div></section>
  <section class="legal-links section-wrap"><h2>${s.legalHeading}</h2><p>${s.legalText}</p><div><a href="${urls[locale].privacy}">${copy[locale].nav.privacy}<span aria-hidden="true">↗</span></a><a href="${appleEula}" target="_blank" rel="noopener noreferrer">${copy[locale].footer.eula}<span aria-hidden="true">↗</span></a></div></section>`;
}

function privacy(locale) {
  const p = copy[locale].privacy;
  const contents = p.sections.map(([title], index) => `<a href="#section-${index + 1}">${escapeHtml(title)}</a>`).join('');
  const sections = p.sections.map(([title, html], index) => `<section id="section-${index + 1}" class="policy-section"><h2>${escapeHtml(title)}</h2>${html}</section>`).join('');
  return `<section class="document-hero section-wrap policy-hero"><span class="eyebrow">${p.eyebrow}</span><h1>${p.heading}</h1><p>${p.lead}</p><span class="updated">${p.updated}</span></section><div class="policy-layout section-wrap"><nav class="policy-toc" aria-label="${locale === 'ko' ? '목차' : 'Contents'}">${contents}</nav><article class="policy-body">${sections}</article></div>`;
}

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
await cp(join(root, 'assets'), join(output, 'assets'), { recursive: true });
await cp(join(root, 'style.css'), join(output, 'style.css'));
const screenshots = { ko: await screenshotNames('ko'), en: await screenshotNames('en') };
for (const locale of ['ko', 'en']) {
  for (const [page, renderer] of Object.entries({ home: landing, support, privacy })) {
    const path = join(output, urls[locale][page].replace(/^\//, ''), 'index.html');
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, pageShell(locale, page, renderer(locale, screenshots[locale])), 'utf8');
  }
}
await writeFile(join(output, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${baseUrl}/sitemap.xml\n`);
await writeFile(join(output, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${Object.values(urls).flatMap((paths) => Object.values(paths)).map((path) => `<url><loc>${baseUrl}${path}</loc></url>`).join('')}</urlset>`);
console.log(`Built six pages with ${screenshots.ko.length} Korean and ${screenshots.en.length} English screenshots.`);
