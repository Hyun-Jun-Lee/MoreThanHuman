// Web Speech API - Voice Input and Output
let recognition = null;
let synthesis = window.speechSynthesis;
let isListening = false;

// Initialize Speech Recognition
if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    recognition = new SpeechRecognition();

    recognition.continuous = false;
    recognition.interimResults = false;
    recognition.lang = 'en-US';

    recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript;
        const input = document.getElementById('message-input');
        input.value = transcript;
        isListening = false;
        updateVoiceButton();
    };

    recognition.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        isListening = false;
        updateVoiceButton();
    };

    recognition.onend = () => {
        isListening = false;
        updateVoiceButton();
    };
}

// Voice button click handler
document.addEventListener('DOMContentLoaded', () => {
    const voiceBtn = document.getElementById('voice-btn');

    if (voiceBtn) {
        voiceBtn.addEventListener('click', () => {
            if (!recognition) {
                alert('Speech recognition is not supported in your browser.');
                return;
            }

            if (isListening) {
                recognition.stop();
                isListening = false;
            } else {
                recognition.start();
                isListening = true;
            }

            updateVoiceButton();
        });
    }
});

// Update voice button appearance
function updateVoiceButton() {
    const voiceBtn = document.getElementById('voice-btn');
    const icon = voiceBtn.querySelector('.material-symbols-outlined');

    if (isListening) {
        icon.textContent = 'mic_off';
        voiceBtn.classList.add('bg-red-500/10', 'text-red-500');
    } else {
        icon.textContent = 'mic';
        voiceBtn.classList.remove('bg-red-500/10', 'text-red-500');
    }
}

// Speak text using TTS
function speakText(text, buttonElement = null) {
    if (!synthesis) {
        console.error('Speech synthesis not supported');
        return;
    }

    // Cancel any ongoing speech
    synthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'en-US';
    utterance.rate = 0.9;
    utterance.pitch = 1.0;

    // Update button icon to pause when speaking starts
    if (buttonElement) {
        const icon = buttonElement.querySelector('.material-symbols-outlined');
        if (icon) {
            icon.textContent = 'pause';
            buttonElement.classList.add('text-primary');
        }
    }

    // Restore icon when speech ends
    utterance.onend = () => {
        if (buttonElement) {
            const icon = buttonElement.querySelector('.material-symbols-outlined');
            if (icon) {
                icon.textContent = 'volume_up';
                buttonElement.classList.remove('text-primary');
            }
        }
    };

    synthesis.speak(utterance);
}

// Auto-speak AI responses (optional feature)
let autoSpeak = localStorage.getItem('autoSpeak') !== 'false'; // Default to true

function toggleAutoSpeak() {
    autoSpeak = !autoSpeak;
    localStorage.setItem('autoSpeak', autoSpeak);
    updateAutoSpeakButton();
    return autoSpeak;
}

// Update auto-speak toggle button appearance
function updateAutoSpeakButton() {
    const toggleBtn = document.getElementById('auto-speak-toggle');
    if (!toggleBtn) return;

    const icon = toggleBtn.querySelector('.material-symbols-outlined');
    if (autoSpeak) {
        icon.textContent = 'volume_up';
        toggleBtn.title = 'Auto-play: ON';
    } else {
        icon.textContent = 'volume_off';
        toggleBtn.title = 'Auto-play: OFF';
    }
}

// Initialize auto-speak button on page load
document.addEventListener('DOMContentLoaded', () => {
    updateAutoSpeakButton();

    const autoSpeakToggle = document.getElementById('auto-speak-toggle');
    if (autoSpeakToggle) {
        autoSpeakToggle.addEventListener('click', () => {
            toggleAutoSpeak();
        });
    }
});
