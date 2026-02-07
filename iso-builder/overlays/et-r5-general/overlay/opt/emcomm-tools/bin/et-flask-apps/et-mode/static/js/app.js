/*
 * et-mode - Mode Selection JavaScript
 * Author: Sylvain Deguire (VA2OPS)
 * Date: January 2026
 */

let selectedMode = null;
let selectedModem = null;

// Select a mode card
function selectMode(modeId) {
    selectedMode = modeId;
    
    // Update UI
    document.querySelectorAll('.mode-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    const card = document.querySelector(`.mode-card[data-mode="${modeId}"]`);
    if (card) {
        card.classList.add('selected');
    }
    
    // Auto-scroll to button on small screens
    setTimeout(() => {
        const btn = document.getElementById('start-btn');
        if (btn && window.innerHeight < 700) {
            btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }, 200);
}

// Select a modem card
function selectModem(modemId) {
    selectedModem = modemId;
    
    // Update UI
    document.querySelectorAll('.modem-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    const card = document.querySelector(`.modem-card[data-modem="${modemId}"]`);
    if (card) {
        card.classList.add('selected');
    }
    
    // Enable start button
    const startBtn = document.getElementById('start-btn');
    if (startBtn) {
        startBtn.disabled = false;
    }
    
    // Auto-scroll
    setTimeout(() => {
        if (startBtn && window.innerHeight < 700) {
            startBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }, 200);
}

// Start the selected mode
async function startMode() {
    if (!selectedMode) {
        alert('Please select a mode');
        return;
    }
    
    showLoading('Starting mode...');
    
    try {
        const response = await fetch('/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                mode_id: selectedMode,
                modem: selectedModem 
            })
        });
        
        const result = await response.json();
        
        hideLoading();
        
        if (result.needs_modem) {
            // Redirect to modem selection
            window.location.href = `/modem/${selectedMode}`;
        } else if (result.success) {
            showResult(true, result.log);
        } else {
            showResult(false, result.log || [result.error]);
        }
    } catch (error) {
        hideLoading();
        showResult(false, ['Connection error: ' + error.message]);
    }
}

// Start mode with modem (from modem selection page)
async function startModeWithModem(modeId) {
    if (!selectedModem) {
        alert('Please select a modem');
        return;
    }
    
    showLoading('Starting mode...');
    
    try {
        const response = await fetch('/start', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                mode_id: modeId,
                modem: selectedModem 
            })
        });
        
        const result = await response.json();
        
        hideLoading();
        
        if (result.success) {
            showResult(true, result.log);
        } else {
            showResult(false, result.log || [result.error]);
        }
    } catch (error) {
        hideLoading();
        showResult(false, ['Connection error: ' + error.message]);
    }
}

// Stop all services
async function stopAll() {
    showLoading('Stopping all services...');
    
    try {
        const response = await fetch('/stop', {
            method: 'POST'
        });
        
        const result = await response.json();
        
        hideLoading();
        
        if (result.success) {
            // Reload page to show updated status
            window.location.reload();
        } else {
            alert('Error stopping services');
        }
    } catch (error) {
        hideLoading();
        alert('Connection error');
    }
}

// Show loading overlay
function showLoading(text) {
    const overlay = document.createElement('div');
    overlay.className = 'loading-overlay';
    overlay.id = 'loading-overlay';
    overlay.innerHTML = `
        <div class="spinner-large"></div>
        <div class="loading-text">${text}</div>
    `;
    document.body.appendChild(overlay);
}

// Hide loading overlay
function hideLoading() {
    const overlay = document.getElementById('loading-overlay');
    if (overlay) {
        overlay.remove();
    }
}

// Show result
function showResult(success, log) {
    const container = document.querySelector('.card-body');
    if (!container) return;
    
    const logHtml = log.map(line => {
        const cls = line.toLowerCase().includes('error') || line.toLowerCase().includes('failed') 
            ? 'error' 
            : line.toLowerCase().includes('started') || line.toLowerCase().includes('running')
                ? 'success' 
                : '';
        return `<div class="log-line ${cls}">${line}</div>`;
    }).join('');
    
    container.innerHTML = `
        <div class="result-icon ${success ? 'success' : 'error'}">
            ${success ? '✓' : '✗'}
        </div>
        <h2 style="text-align: center; margin-bottom: 16px;">
            ${success ? (document.documentElement.lang === 'fr' ? 'Mode Démarré' : 'Mode Started') : 'Error'}
        </h2>
        <div class="log-output">${logHtml}</div>
        <div class="btn-group" style="justify-content: center;">
            <a href="/" class="btn btn-primary">← ${document.documentElement.lang === 'fr' ? 'Retour' : 'Back'}</a>
            <button onclick="shutdownAndClose()" class="btn btn-secondary">
                ${document.documentElement.lang === 'fr' ? 'Fermer' : 'Close'}
            </button>
        </div>
    `;
}

// Shutdown server and close
function shutdownAndClose() {
    fetch('/shutdown', { method: 'POST' }).catch(() => {});
    setTimeout(() => {
        window.close();
    }, 500);
}

// Double-click to start immediately
function handleDoubleClick(modeId, needsModem) {
    selectedMode = modeId;
    
    // Update selection visually
    document.querySelectorAll('.mode-card').forEach(card => {
        card.classList.remove('selected');
    });
    document.querySelector(`.mode-card[data-mode="${modeId}"]`).classList.add('selected');
    
    if (needsModem) {
        window.location.href = `/modem/${modeId}`;
    } else {
        startMode();
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    // Add double-click handlers to mode cards
    document.querySelectorAll('.mode-card').forEach(card => {
        const modeId = card.dataset.mode;
        const needsModem = card.dataset.needsModem === 'true';
        
        card.addEventListener('dblclick', () => handleDoubleClick(modeId, needsModem));
    });
});
