// Chat functionality
let conversationId = null;
let searchContext = null;
let lastUserMessage = null; // Store last message for retry
let conversationType = 'FREE_CHAT'; // FREE_CHAT or ROLE_PLAYING
let roleCharacter = null;
let isSending = false; // Track if message is being sent

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
        document.getElementById('welcome-message').classList.remove('hidden');
    } else {
        // Show conversation setup for new conversations
        document.getElementById('conversation-setup').classList.remove('hidden');
        document.getElementById('conversation-setup').classList.add('flex');
        initializeConversationSetup();
    }

    // Event listeners
    document.getElementById('send-btn').addEventListener('click', () => sendMessage());
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

    // Speaker button and retry button event delegation
    const messagesContainer = document.getElementById('messages-list');
    messagesContainer.addEventListener('click', (e) => {
        // Handle speaker button clicks
        const speakerBtn = e.target.closest('.speaker-btn');
        if (speakerBtn) {
            const text = speakerBtn.dataset.text;
            if (text) {
                speakText(text, speakerBtn);
            }
            return;
        }

        // Handle retry button clicks
        const retryBtn = e.target.closest('.retry-btn');
        if (retryBtn && lastUserMessage) {
            // Remove retry message
            const retryMessage = retryBtn.closest('.retry-message');
            if (retryMessage) {
                retryMessage.remove();
            }
            // Retry with last message
            sendMessage(lastUserMessage);
        }
    });

    // Load sidebar conversations
    loadSidebarConversations();

    // Warn on page refresh if message is being typed on new conversation page
    if (conversationId === 'new') {
        window.addEventListener('beforeunload', (e) => {
            const input = document.getElementById('message-input');
            if (input.value.trim()) {
                e.preventDefault();
                e.returnValue = '';
            }
        });
    }
});

// Initialize conversation setup UI
function initializeConversationSetup() {
    const freeChatBtn = document.getElementById('type-free-chat');
    const rolePlayingBtn = document.getElementById('type-role-playing');
    const freeChatOptions = document.getElementById('free-chat-options');
    const rolePlayingOptions = document.getElementById('role-playing-options');
    const startBtn = document.getElementById('start-conversation-btn');
    const messageInput = document.getElementById('message-input');

    // Hide message input initially
    messageInput.closest('footer').classList.add('hidden');

    // Type selection handlers
    freeChatBtn.addEventListener('click', () => {
        conversationType = 'FREE_CHAT';
        freeChatBtn.classList.add('border-primary', 'bg-primary/10');
        rolePlayingBtn.classList.remove('border-primary', 'bg-primary/10');
        freeChatOptions.classList.remove('hidden');
        rolePlayingOptions.classList.add('hidden');
        startBtn.classList.remove('hidden');
    });

    rolePlayingBtn.addEventListener('click', () => {
        conversationType = 'ROLE_PLAYING';
        rolePlayingBtn.classList.add('border-primary', 'bg-primary/10');
        freeChatBtn.classList.remove('border-primary', 'bg-primary/10');
        rolePlayingOptions.classList.remove('hidden');
        freeChatOptions.classList.add('hidden');
        startBtn.classList.remove('hidden');
    });

    // Start conversation button handler
    startBtn.addEventListener('click', () => {
        if (conversationType === 'ROLE_PLAYING') {
            roleCharacter = document.getElementById('role-character').value.trim();
            if (!roleCharacter) {
                alert('Please enter a character role for role-playing');
                return;
            }
        }

        // Enable search context if checkbox is checked for free chat
        if (conversationType === 'FREE_CHAT' && document.getElementById('enable-search-context').checked) {
            document.getElementById('search-modal').classList.remove('hidden');
            return; // Wait for search to complete
        }

        // Hide setup, show input, and show welcome message
        startConversationUI();
    });
}

// Start conversation UI
function startConversationUI() {
    document.getElementById('conversation-setup').classList.add('hidden');
    document.getElementById('conversation-setup').classList.remove('flex');
    document.getElementById('message-input').closest('footer').classList.remove('hidden');
    document.getElementById('welcome-message').classList.remove('hidden');

    // Focus on message input
    document.getElementById('message-input').focus();
}

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
async function sendMessage(retryMessage = null) {
    // Prevent sending if already sending
    if (isSending) {
        console.log('Message already being sent, please wait...');
        return;
    }

    const input = document.getElementById('message-input');
    const message = retryMessage || input.value.trim();

    if (!message) return;

    isSending = true;

    // Store message for potential retry
    lastUserMessage = message;

    // Clear input only if not retrying
    if (!retryMessage) {
        input.value = '';
    }

    // Add user message to UI (only if not retrying)
    if (!retryMessage) {
        addUserMessage(message);
    }

    // Show loading indicator
    addLoadingMessage();

    try {
        let response;

        if (!conversationId || conversationId === 'new') {
            // Start new conversation
            response = await fetch('/api/conversations/start/', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    first_message: message,
                    search_context: searchContext,
                    conversation_type: conversationType,
                    role_character: roleCharacter
                })
            });

            // Check for rate limit error
            if (response.status === 429) {
                removeLoadingMessage();
                const errorData = await response.json();
                addRetryMessage(errorData.detail || '사용 한도에 도달했습니다. 1-2분 후 다시 시도해주세요.');
                return;
            }

            const data = await response.json();

            if (data.success && data.data) {
                conversationId = data.data.conversation_id;
                // Update URL without reload
                window.history.pushState({}, '', `/conversations/${conversationId}`);

                // Update sidebar with new conversation
                loadSidebarConversations();

                // Remove any retry messages on success
                removeRetryMessages();

                // Remove loading and add grammar feedback to user message
                removeLoadingMessage();
                addGrammarFeedback(data.data.grammar_feedback);
                addAIMessage(data.data.response);
            }
        } else {
            // Continue conversation
            response = await fetch(`/api/conversations/${conversationId}/message/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: message })
            });

            // Check for rate limit error
            if (response.status === 429) {
                removeLoadingMessage();
                const errorData = await response.json();
                addRetryMessage(errorData.detail || '사용 한도에 도달했습니다. 1-2분 후 다시 시도해주세요.');
                return;
            }

            // Check for not found error (conversation deleted or doesn't exist)
            if (response.status === 404) {
                removeLoadingMessage();
                window.location.href = '/conversations/new';
                return;
            }

            const data = await response.json();

            if (data.success && data.data) {
                // Remove any retry messages on success
                removeRetryMessages();

                // Remove loading and add grammar feedback to user message
                removeLoadingMessage();
                addGrammarFeedback(data.data.grammar_feedback);
                addAIMessage(data.data.response);
            }
        }

        scrollToBottom();
    } catch (error) {
        removeLoadingMessage();
        console.error('Failed to send message:', error);
        alert('Failed to send message. Please try again.');
    } finally {
        isSending = false;
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

            // If we're in setup mode, start the conversation UI
            if (conversationId === 'new' && document.getElementById('conversation-setup').classList.contains('flex')) {
                startConversationUI();
            } else {
                alert('Search context loaded! Your next message will use this information.');
            }
        }
    } catch (error) {
        console.error('Search failed:', error);
        alert('Search failed. Please try again.');
    }
}

// Add retry message for rate limit errors
function addRetryMessage(errorMessage) {
    const messagesContainer = document.getElementById('messages-list');

    const retryHtml = `
        <div class="flex items-start gap-3 self-start max-w-xl retry-message">
            <div class="bg-yellow-500/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                <span class="material-symbols-outlined text-yellow-600 dark:text-yellow-400">schedule</span>
            </div>
            <div class="flex flex-1 flex-col gap-2 items-start">
                <p class="text-yellow-800 dark:text-yellow-200 text-sm font-bold leading-normal">Rate Limit</p>
                <p class="text-base font-normal leading-relaxed rounded-lg px-4 py-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800/50">${escapeHtml(errorMessage)}</p>
                <button class="retry-btn flex items-center gap-2 px-4 py-2 rounded-lg bg-primary text-white text-sm font-medium hover:bg-primary/90 transition-colors">
                    <span class="material-symbols-outlined text-lg">refresh</span>
                    <span>재시도</span>
                </button>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', retryHtml);
    scrollToBottom();
}

// Remove retry messages from UI
function removeRetryMessages() {
    const retryMessages = document.querySelectorAll('.retry-message');
    retryMessages.forEach(msg => msg.remove());
}

// Add loading message
function addLoadingMessage() {
    const messagesContainer = document.getElementById('messages-list');

    const loadingHtml = `
        <div class="flex items-end gap-3 self-start max-w-xl loading-message">
            <div class="bg-primary/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                <span class="material-symbols-outlined text-primary">smart_toy</span>
            </div>
            <div class="flex flex-1 flex-col gap-1 items-start">
                <p class="text-subtle-light dark:text-subtle-dark text-sm font-medium leading-normal">MoreThanHuman AI</p>
                <p class="text-base font-normal leading-relaxed rounded-lg px-4 py-3 bg-surface-light dark:bg-surface-dark shadow-sm">
                    <span class="inline-flex items-center gap-1">
                        응답중<span class="animate-pulse">...</span>
                    </span>
                </p>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', loadingHtml);
    scrollToBottom();
}

// Remove loading message
function removeLoadingMessage() {
    const loadingMessage = document.querySelector('.loading-message');
    if (loadingMessage) {
        loadingMessage.remove();
    }
}

// Add user message to UI
function addUserMessage(content) {
    const messagesContainer = document.getElementById('messages-list');

    const messageHtml = `
        <div class="user-message-container flex flex-col items-end gap-2 self-end max-w-xl">
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

// Add grammar feedback to last user message
function addGrammarFeedback(grammarFeedback) {
    if (!grammarFeedback) return;

    const userMessages = document.querySelectorAll('.user-message-container');
    const lastUserMessage = userMessages[userMessages.length - 1];

    if (!lastUserMessage) return;

    let feedbackHtml = '';
    if (grammarFeedback.has_errors) {
        feedbackHtml = `
            <div class="flex flex-col gap-1 items-end bg-yellow-50 dark:bg-yellow-900/20 p-3 rounded-lg border border-yellow-200 dark:border-yellow-800/50 w-full">
                <p class="text-yellow-800 dark:text-yellow-200 text-sm font-bold leading-tight">Correction</p>
                <p class="text-text-light dark:text-text-dark text-base font-normal leading-relaxed text-right">${escapeHtml(grammarFeedback.corrected_text || '')}</p>
            </div>
        `;
    } else {
        feedbackHtml = `
            <div class="flex items-center justify-end gap-2 p-2 w-full">
                <span class="material-symbols-outlined text-green-600 dark:text-green-400 text-xl">check_circle</span>
            </div>
        `;
    }

    lastUserMessage.insertAdjacentHTML('beforeend', feedbackHtml);
}

// Add AI message to UI
function addAIMessage(content) {
    const messagesContainer = document.getElementById('messages-list');

    const messageHtml = `
        <div class="flex items-end gap-3 self-start max-w-xl">
            <div class="bg-primary/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                <span class="material-symbols-outlined text-primary">smart_toy</span>
            </div>
            <div class="flex flex-1 flex-col gap-1 items-start">
                <div class="flex items-center gap-2">
                    <p class="text-subtle-light dark:text-subtle-dark text-sm font-medium leading-normal">MoreThanHuman AI</p>
                    <button class="speaker-btn flex items-center justify-center size-7 rounded-full hover:bg-primary/10 transition-colors" data-text="${escapeHtml(content)}" title="Play audio">
                        <span class="material-symbols-outlined text-lg text-subtle-light dark:text-subtle-dark">volume_up</span>
                    </button>
                </div>
                <p class="text-base font-normal leading-relaxed rounded-lg px-4 py-3 bg-surface-light dark:bg-surface-dark shadow-sm">${escapeHtml(content)}</p>
            </div>
        </div>
    `;

    messagesContainer.insertAdjacentHTML('beforeend', messageHtml);

    // Auto-play if enabled
    if (typeof autoSpeak !== 'undefined' && autoSpeak) {
        // Get the speaker button we just added
        const speakerButtons = messagesContainer.querySelectorAll('.speaker-btn');
        const lastButton = speakerButtons[speakerButtons.length - 1];
        if (lastButton) {
            speakText(content, lastButton);
        }
    }
}

// Append message from API data
function appendMessage(msg) {
    if (msg.role === 'user') {
        addUserMessage(msg.content);
        // Add grammar feedback if available
        if (msg.grammar_feedback) {
            addGrammarFeedback(msg.grammar_feedback);
        }
    } else if (msg.role === 'assistant') {
        // Add AI message without auto-play for historical messages
        const messagesContainer = document.getElementById('messages-list');

        const messageHtml = `
            <div class="flex items-end gap-3 self-start max-w-xl">
                <div class="bg-primary/20 rounded-full w-10 h-10 shrink-0 flex items-center justify-center">
                    <span class="material-symbols-outlined text-primary">smart_toy</span>
                </div>
                <div class="flex flex-1 flex-col gap-1 items-start">
                    <div class="flex items-center gap-2">
                        <p class="text-subtle-light dark:text-subtle-dark text-sm font-medium leading-normal">MoreThanHuman AI</p>
                        <button class="speaker-btn flex items-center justify-center size-7 rounded-full hover:bg-primary/10 transition-colors" data-text="${escapeHtml(msg.content)}" title="Play audio">
                            <span class="material-symbols-outlined text-lg text-subtle-light dark:text-subtle-dark">volume_up</span>
                        </button>
                    </div>
                    <p class="text-base font-normal leading-relaxed rounded-lg px-4 py-3 bg-surface-light dark:bg-surface-dark shadow-sm">${escapeHtml(msg.content)}</p>
                </div>
            </div>
        `;

        messagesContainer.insertAdjacentHTML('beforeend', messageHtml);
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
                <span class="text-sm font-medium truncate">${conv.title || '#' + conv.id.substring(0, 8)}</span>
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
