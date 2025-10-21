// Dark mode toggle functionality
(function() {
    const html = document.documentElement;

    // Load theme from localStorage
    const savedTheme = localStorage.getItem('theme') || 'light';
    html.classList.remove('light', 'dark');
    html.classList.add(savedTheme);

    // Toggle function
    window.toggleTheme = function() {
        const current = html.classList.contains('dark') ? 'dark' : 'light';
        const next = current === 'dark' ? 'light' : 'dark';

        html.classList.remove(current);
        html.classList.add(next);
        localStorage.setItem('theme', next);
    };
})();
