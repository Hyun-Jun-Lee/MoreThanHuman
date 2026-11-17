const page = document.body.dataset.page;
let csrfToken = '';

async function request(path, options = {}) {
  const response = await fetch(path, { credentials: 'same-origin', ...options });
  const payload = await response.json().catch(() => ({}));
  if (response.status === 401) {
    window.location.assign('/admin');
    throw new Error('관리자 세션이 만료됐어요.');
  }
  if (!response.ok) {
    const detail = payload.detail ?? payload.error;
    throw new Error(typeof detail === 'string' ? detail : '요청을 처리하지 못했어요.');
  }
  return payload.data;
}

async function write(path, method, body) {
  return request(path, {
    method,
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

function showError(element, error) {
  element.textContent = error.message || '요청을 처리하지 못했어요.';
  element.hidden = false;
}

function clearError(element) {
  element.textContent = '';
  element.hidden = true;
}

function formatTime(value) {
  if (!value) return '기한 없음';
  const normalized = /(?:Z|[+-]\d\d:\d\d)$/.test(value) ? value : `${value}Z`;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? '시각 확인 필요' : new Intl.DateTimeFormat('ko-KR', {
    year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(date);
}

function planName(plan) {
  return { free: 'Free', advance: 'Advance', plus: 'Plus' }[plan] ?? '—';
}

function sourceName(source) {
  return { free: '무료', apple: 'Apple', manual: '수동 부여', admin: '관리자' }[source] ?? source;
}

async function initializeSession() {
  const state = await request('/api/admin/access/status/');
  csrfToken = state.csrf_token;
  return state;
}

async function logout() {
  const error = document.getElementById('global-error');
  const button = document.getElementById('logout');
  clearError(error);
  button.disabled = true;
  try {
    if (!csrfToken) await initializeSession();
    await write('/api/admin/access/logout/', 'POST');
    window.location.assign('/admin/login');
  } catch (cause) {
    showError(error, cause);
    button.disabled = false;
  }
}

document.getElementById('logout')?.addEventListener('click', logout);

if (page === 'login') {
  const form = document.getElementById('code-form');
  const error = document.getElementById('entry-error');
  const button = form.querySelector('button[type=submit]');
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    clearError(error);
    button.disabled = true;
    try {
      const state = await request('/api/admin/access/verify/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: form.elements.code.value }),
      });
      csrfToken = state.csrf_token;
      form.elements.code.value = '';
      window.location.assign('/admin');
    } catch (cause) {
      showError(error, cause);
    } finally {
      button.disabled = false;
    }
  });
}

if (page === 'dashboard') {
  const filters = document.getElementById('filters');
  const list = document.getElementById('user-list');
  const listError = document.getElementById('list-error');
  const detailError = document.getElementById('detail-error');
  const grantForm = document.getElementById('grant-form');
  let offset = 0;
  let total = 0;
  let selectedId = null;
  let historyOffset = 0;
  let usersRequestId = 0;
  let detailRequestId = 0;
  let historyRequestId = 0;
  let mutationInFlight = false;
  let manualAvailable = false;
  const limit = 20;

  function addText(parent, tag, value, className) {
    const element = document.createElement(tag);
    element.textContent = value ?? '';
    if (className) element.className = className;
    parent.appendChild(element);
    return element;
  }

  function renderUsers(users) {
    list.replaceChildren();
    if (!users.length) {
      addText(list, 'p', '조건에 맞는 사용자가 없어요.', 'empty');
    }
    for (const user of users) {
      const row = document.createElement('button');
      row.type = 'button';
      row.className = `user-row${selectedId === user.id ? ' selected' : ''}`;
      const person = document.createElement('span');
      addText(person, 'strong', user.nickname || user.name || user.email);
      addText(person, 'small', user.email);
      row.appendChild(person);
      addText(row, 'span', user.is_admin ? 'ADMIN' : planName(user.effective.plan),
        `plan-pill${user.is_admin ? ' admin' : ''}`);
      row.addEventListener('click', () => {
        selectedId = user.id;
        historyOffset = 0;
        for (const item of list.querySelectorAll('.user-row')) item.classList.remove('selected');
        row.classList.add('selected');
        loadDetail();
      });
      list.appendChild(row);
    }
  }

  async function loadUsers() {
    const requestId = ++usersRequestId;
    const requestedOffset = offset;
    clearError(listError);
    list.replaceChildren();
    addText(list, 'p', '사용자를 불러오는 중이에요.', 'empty');
    const params = new URLSearchParams({ limit: String(limit), offset: String(requestedOffset) });
    for (const key of ['q', 'plan', 'source', 'is_admin']) {
      const value = filters.elements[key].value.trim();
      if (value) params.set(key, value);
    }
    try {
      const data = await request(`/api/admin/users/?${params}`);
      if (requestId !== usersRequestId) return;
      total = data.total_count;
      renderUsers(data.results);
      document.getElementById('user-count').textContent = `${total}명`;
      document.getElementById('page-label').textContent = total ? `${requestedOffset + 1}–${Math.min(total, requestedOffset + limit)} / ${total}` : '0명';
      document.getElementById('prev-page').disabled = requestedOffset === 0;
      document.getElementById('next-page').disabled = requestedOffset + limit >= total;
    } catch (cause) {
      if (requestId !== usersRequestId) return;
      list.replaceChildren();
      showError(listError, cause);
    }
  }

  function renderEntitlement(data) {
    manualAvailable = Boolean(data.manual);
    document.getElementById('effective-plan').textContent = planName(data.effective.plan);
    document.getElementById('effective-detail').textContent = data.effective.source === 'admin'
      ? '관리자 · 구독 기능 무제한' : `${sourceName(data.effective.source)} · ${formatTime(data.effective.expires_at)}`;
    document.getElementById('apple-plan').textContent = planName(data.apple.plan);
    document.getElementById('apple-detail').textContent = data.apple.plan === 'free'
      ? '유효한 구독 없음' : `${data.apple.status} · ${formatTime(data.apple.expires_at)}`;
    document.getElementById('manual-plan').textContent = data.manual ? planName(data.manual.plan) : '없음';
    document.getElementById('manual-detail').textContent = data.manual
      ? `예약 철회: ${formatTime(data.manual.revoke_at)}` : '현재 수동 부여 없음';
    document.getElementById('revoke-button').disabled = mutationInFlight || !manualAvailable;
  }

  function renderHistory(data) {
    const history = document.getElementById('history-list');
    history.replaceChildren();
    if (!data.results.length) addText(history, 'p', '부여 이력이 없어요.', 'empty');
    for (const grant of data.results) {
      const row = document.createElement('div');
      row.className = 'history-row';
      const main = document.createElement('div');
      addText(main, 'strong', planName(grant.plan));
      addText(main, 'small', `부여 ${formatTime(grant.created_at)}`);
      row.appendChild(main);
      addText(row, 'span', grant.revoked_at ? `철회 ${formatTime(grant.revoked_at)}` :
        grant.revoke_at ? `예약 ${formatTime(grant.revoke_at)}` : '기한 없음');
      history.appendChild(row);
    }
    document.getElementById('history-page').textContent = data.total_count
      ? `${historyOffset + 1}–${Math.min(data.total_count, historyOffset + 20)} / ${data.total_count}` : '0건';
    document.getElementById('history-prev').disabled = historyOffset === 0;
    document.getElementById('history-next').disabled = historyOffset + 20 >= data.total_count;
  }

  async function loadHistory() {
    if (!selectedId) return;
    const requestId = ++historyRequestId;
    const userId = selectedId;
    const requestedOffset = historyOffset;
    const data = await request(`/api/admin/users/${userId}/manual-entitlement/history/?limit=20&offset=${requestedOffset}`);
    if (requestId === historyRequestId && selectedId === userId && historyOffset === requestedOffset) renderHistory(data);
  }

  async function loadDetail() {
    if (!selectedId) return;
    const requestId = ++detailRequestId;
    const userId = selectedId;
    clearError(detailError);
    const placeholder = document.getElementById('detail-placeholder');
    const content = document.getElementById('detail-content');
    placeholder.textContent = '사용자를 불러오는 중이에요.';
    placeholder.hidden = false;
    content.hidden = true;
    try {
      const [user, entitlement] = await Promise.all([
        request(`/api/admin/users/${userId}/`),
        request(`/api/admin/users/${userId}/entitlement/`),
      ]);
      if (requestId !== detailRequestId || selectedId !== userId) return;
      document.getElementById('detail-title').textContent = user.nickname || user.name || user.email;
      document.getElementById('detail-email').textContent = user.email;
      document.getElementById('detail-id').textContent = user.id;
      document.getElementById('detail-admin').hidden = !user.is_admin;
      renderEntitlement(entitlement);
      await loadHistory();
      if (requestId !== detailRequestId || selectedId !== userId) return;
      placeholder.hidden = true;
      content.hidden = false;
    } catch (cause) {
      if (requestId === detailRequestId && selectedId === userId) {
        placeholder.textContent = '사용자를 불러오지 못했어요.';
        showError(detailError, cause);
      }
    }
  }

  filters.addEventListener('submit', (event) => { event.preventDefault(); offset = 0; loadUsers(); });
  for (const field of filters.querySelectorAll('select')) {
    field.addEventListener('change', () => { offset = 0; loadUsers(); });
  }
  document.getElementById('prev-page').addEventListener('click', () => { offset = Math.max(0, offset - limit); loadUsers(); });
  document.getElementById('next-page').addEventListener('click', () => { offset += limit; loadUsers(); });
  document.getElementById('history-prev').addEventListener('click', () => { historyOffset = Math.max(0, historyOffset - 20); loadHistory().catch((cause) => showError(detailError, cause)); });
  document.getElementById('history-next').addEventListener('click', () => { historyOffset += 20; loadHistory().catch((cause) => showError(detailError, cause)); });

  function setMutationBusy(busy) {
    mutationInFlight = busy;
    grantForm.querySelector('button[type=submit]').disabled = busy;
    document.getElementById('revoke-button').disabled = busy || !manualAvailable;
  }

  grantForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!selectedId || mutationInFlight) return;
    clearError(detailError);
    const localTime = grantForm.elements.revoke_at.value;
    const revokeAt = localTime ? new Date(localTime) : null;
    if (revokeAt && (Number.isNaN(revokeAt.getTime()) || revokeAt <= new Date())) {
      showError(detailError, new Error('예약 철회 시각은 미래여야 해요.'));
      return;
    }
    setMutationBusy(true);
    try {
      await write(`/api/admin/users/${selectedId}/manual-entitlement/`, 'PUT', {
        plan: grantForm.elements.plan.value,
        revoke_at: revokeAt ? revokeAt.toISOString() : null,
      });
      await Promise.all([loadDetail(), loadUsers()]);
    } catch (cause) {
      showError(detailError, cause);
    } finally {
      setMutationBusy(false);
    }
  });

  document.getElementById('revoke-button').addEventListener('click', async () => {
    if (!selectedId || mutationInFlight || !window.confirm('이 사용자의 수동 구독 권한을 즉시 철회할까요?')) return;
    setMutationBusy(true);
    clearError(detailError);
    try {
      await write(`/api/admin/users/${selectedId}/manual-entitlement/`, 'DELETE');
      await Promise.all([loadDetail(), loadUsers()]);
    } catch (cause) {
      showError(detailError, cause);
    } finally {
      setMutationBusy(false);
    }
  });

  initializeSession().then((state) => {
    if (!state.verified) { window.location.assign('/admin'); return; }
    loadUsers();
  }).catch((cause) => showError(listError, cause));
}
