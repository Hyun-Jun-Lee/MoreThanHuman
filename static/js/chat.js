// Chat functionality
let conversationId = null;
let searchContext = null;

// Get conversation ID from URL
function getConversationId() {
    const path = window.location.pathname;
    const match = path.match(/\/conversations\/([a-f0-9-]+)/);
    return match ? match[1] : null;
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    conversationId = getConversationId();

    if (conversationId && conversationId !== 'new') {
        loadConversation(conversationId);
    }

    // Event listeners
    document.getElementById('send-btn').addEventListener('click', sendMessage);
    document.getElementById('message-input').addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    // Search modal
    document.getElementById('search-btn').addEventListener('click', () => {
        document.getElementById('search-modal').classList.remove('hidden');
    });
    document.getElementById('search-cancel').addEventListener('click', () => {
        document.getElementById('search-modal').classList.add('hidden');
    });
    document.getElementById('search-submit').addEventListener('click', performSearch);

    // Load sidebar conversations
    loadSidebarConversations();
});

// Load conversation messages
async function loadConversation(id) {
    try {
        const response = await fetch(`/api/conversations/${id}/messages/`);
        const data = await response.json();

        if (data.success && data.data) {
            const messagesContainer = document.getElementById('messages-list');
            messagesContainer.innerHTML = '';

            data.data.forEach(msg => {
                appendMessage(msg);
            });

            scrollToBottom();
        }
    } catch (error) {
        console.error('Failed to load conversation:', error);
    }
}

// Send message
async function sendMessage() {
    const input = document.getElementById('message-input');
    const message = input.value.trim();

    if (!message) return;

    // Clear input
    input.value = '';

    // Add user message to UI
    addUserMessage(message);

    try {
        let response;

        if (!conversationId || conversationId === 'new') {
            // Start new conversation
            response = await fetch('/api/conversations/start/', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    first_message: message,
                    search_context: searchContext
                })
            });

            const data = await response.json();

            if (data.success && data.data) {
                conversationId = data.data.conversation_id;
                // Update URL without reload
                window.history.pushState({}, '', `/conversations/${conversationId}`);

                // Add AI response
                addAIMessage(data.data.response, data.data.grammar_feedback);
            }
        } else {
            // Continue conversation
            response = await fetch(`/api/conversations/${conversationId}/message/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ user_message: message })
            });

            const data = await response.json();

            if (data.success && data.data) {
                addAIMessage(data.data.response, data.data.grammar_feedback);
            }
        }

        scrollToBottom();
    } catch (error) {
        console.error('Failed to send message:', error);
        alert('Failed to send message. Please try again.');
    }
}

// Search for context
async function performSearch() {
    const query = document.getElementById('search-query').value.trim();

    if (!query) return;

    try {
        const response = await fetch('/api/search/', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query })
        });

        const data = await response.json();

        if (data.success && data.data) {
            searchContext = data.data;
            document.getElementById('search-modal').classList.add('hidden');
            alert('Search context loaded! Your next message will use this information.');
        }
    } catch (error) {
        console.error('Search failed:', error);
        alert('Search failed. Please try again.');
    }
}

// Add user message to UI
function addUserMessage(content) {
    const messagesContainer = document.getElementById('messages-list');

    const messageHtml = `
        <div class="flex flex-col items-end gap-2 self-end max-w-xl">
            <div class="flex items-end gap-3 self-end w-full">
                <div class="flex flex-1 flex-col gap-1 items-end">
                    <p class="text-subtle-light dark:text-subtle-dark text-sm font-medium leading-normal">You</p>
                    <p class="text-base font-normal leading-relaxed rounded-lg rounded-br-none px-4 py-3 bg-primary text-white shadow-sm">${escapeHtml(content)}</p>
                </div>
                <div class="bg-primary/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                    <span class="material-symbols-outlined text-primary">person</span>
                </div>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', messageHtml);
}

// Add AI message to UI
function addAIMessage(content, grammarFeedback = null) {
    const messagesContainer = document.getElementById('messages-list');

    let grammarHtml = '';
    if (grammarFeedback && grammarFeedback.has_errors) {
        grammarHtml = `
            <div class="flex flex-col gap-1 items-start bg-yellow-50 dark:bg-yellow-900/20 p-3 rounded-lg border border-yellow-200 dark:border-yellow-800/50 w-[calc(100%-3.25rem)]">
                <p class="text-yellow-800 dark:text-yellow-200 text-sm font-bold leading-tight">Correction</p>
                <p class="text-text-light dark:text-text-dark text-base font-normal leading-relaxed">${grammarFeedback.corrected_text || ''}</p>
            </div>
        `;
    }

    const messageHtml = `
        <div class="flex items-end gap-3 self-start max-w-xl">
            <div class="bg-primary/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                <span class="material-symbols-outlined text-primary">smart_toy</span>
            </div>
            <div class="flex flex-1 flex-col gap-1 items-start">
                <p class="text-subtle-light dark:text-subtle-dark text-sm font-medium leading-normal">MoreThanHuman AI</p>
                <p class="text-base font-normal leading-relaxed rounded-lg px-4 py-3 bg-surface-light dark:bg-surface-dark shadow-sm">${escapeHtml(content)}</p>
                ${grammarHtml}
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', messageHtml);
}

// Append message from API data
function appendMessage(msg) {
    if (msg.role === 'user') {
        addUserMessage(msg.content);
    } else if (msg.role === 'assistant') {
        addAIMessage(msg.content);
    }
}

// Load sidebar conversations
async function loadSidebarConversations() {
    const container = document.getElementById('sidebar-conversation-list');
    if (!container) return;

    try {
        const response = await fetch('/api/conversations/');
        const data = await response.json();

        if (!data.success || !data.data || data.data.length === 0) {
            container.innerHTML = '<p class="text-center text-subtle-light dark:text-subtle-dark text-sm py-4">No conversations</p>';
            return;
        }

        const html = data.data.slice(0, 10).map(conv => `
            <a class="flex items-center gap-3 px-4 py-2 rounded-lg hover:bg-primary/5 ${conv.id === conversationId ? 'bg-primary/10 text-primary' : 'text-text-light dark:text-text-dark'}" href="/conversations/${conv.id}">
                <span class="material-symbols-outlined text-xl">chat_bubble</span>
                <span class="text-sm font-medium truncate">#${conv.id.substring(0, 8)}</span>
            </a>
        `).join('');

        container.innerHTML = html;
    } catch (error) {
        console.error('Failed to load sidebar conversations:', error);
    }
}

// Utility functions
function scrollToBottom() {
    const container = document.getElementById('messages-container');
    container.scrollTop = container.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
