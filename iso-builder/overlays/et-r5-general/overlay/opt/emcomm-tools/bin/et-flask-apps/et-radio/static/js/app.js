/*
 * et-radio - JavaScript
 * Author: Sylvain Deguire (VA2OPS)
 * Date: January 2026
 */

// Select radio card
function selectRadio(radioId) {
    // Update UI
    document.querySelectorAll('.radio-card').forEach(card => {
        card.classList.remove('selected');
    });
    
    const selectedCard = document.querySelector(`.radio-card[data-radio="${radioId}"]`);
    if (selectedCard) {
        selectedCard.classList.add('selected');
    }
    
    // Enable continue button
    const continueBtn = document.getElementById('continue-btn');
    if (continueBtn) {
        continueBtn.disabled = false;
    }
    
    // Auto-scroll to button on small screens
    setTimeout(() => {
        if (continueBtn && window.innerHeight < 700) {
            continueBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }, 200);
}

// Save selection and continue
async function saveAndContinue() {
    const selected = document.querySelector('.radio-card.selected');
    if (!selected) {
        alert('Please select a radio');
        return;
    }
    
    const radioId = selected.dataset.radio;
    const btn = document.getElementById('continue-btn');
    
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Saving...';
    
    try {
        const response = await fetch('/select', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ radio_id: radioId })
        });
        
        const result = await response.json();
        
        if (result.success) {
            window.location.href = result.redirect;
        } else {
            alert(result.error || 'Error saving selection');
            btn.disabled = false;
            btn.innerHTML = 'Continue →';
        }
    } catch (error) {
        alert('Connection error');
        btn.disabled = false;
        btn.innerHTML = 'Continue →';
    }
}

// Shutdown server
function shutdownServer() {
    fetch('/shutdown', { method: 'POST' }).catch(() => {});
}

// Cancel and close window
function cancelAndClose() {
    fetch('/shutdown', { method: 'POST' }).catch(() => {});
    setTimeout(() => {
        window.close();
    }, 300);
}

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    // Pre-select active radio if any
    const activeRadio = document.querySelector('.radio-card.active');
    if (activeRadio) {
        activeRadio.classList.add('selected');
    }
});
