const express = require('express');
const cors    = require('cors');
const path    = require('path');
const fs      = require('fs');
const { execFile } = require('child_process');

const PORT     = 8888;
const PS_SCRIPT = path.join(__dirname, 'smtc.ps1');
const ART_FILE  = path.join(process.env.TEMP || 'C:\\Windows\\Temp', 'mw-art.dat');
const WIDGET_DIR = path.join(__dirname, '..');

const app = express();
app.use(cors());

// ── Platform detection ──────────────────────────────────────────────────────
function detectPlatform(source) {
    if (!source) return 'unknown';
    const s = source.toLowerCase();
    if (s.includes('spotify'))                                           return 'spotify';
    if (s.includes('youtubemusic') || s.includes('youtube-music') ||
        s.includes('ytmusic')      || s.includes('youtube.music'))       return 'youtube';
    if (s.includes('youtube'))                                           return 'youtube';
    if (s.includes('applemusic')   || s.includes('apple.music') ||
        s.includes('itunes'))                                            return 'apple';
    if (s.includes('amazonmusic')  || s.includes('amazon.music') ||
        s.includes('alexa'))                                             return 'amazon';
    if (s.includes('tidal'))                                             return 'tidal';
    if (s.includes('deezer'))                                            return 'deezer';
    if (s.includes('soundcloud'))                                        return 'soundcloud';
    if (s.includes('pandora'))                                           return 'pandora';
    if (s.includes('vlc'))                                               return 'vlc';
    return 'unknown';
}

// ── State ───────────────────────────────────────────────────────────────────
let state    = { playing: false };
let artBuf   = null;
let artMime  = 'image/jpeg';
let artStamp = 0;
let polling  = false;

// ── Poll SMTC via PowerShell ─────────────────────────────────────────────────
function poll() {
    if (polling) return;
    polling = true;

    execFile('powershell', [
        '-ExecutionPolicy', 'Bypass',
        '-NonInteractive',
        '-WindowStyle', 'Hidden',
        '-File', PS_SCRIPT,
    ], { timeout: 4000 }, (err, stdout, stderr) => {
        polling = false;

        if (!err && stdout && stdout.trim()) {
            try {
                const data = JSON.parse(stdout.trim());
                const wasTitle = state.title;

                data.platform = detectPlatform(data.source);
                state = data;

                if (data.hasArt && fs.existsSync(ART_FILE)) {
                    if (data.title !== wasTitle) {
                        artBuf   = fs.readFileSync(ART_FILE);
                        artMime  = data.artMime || 'image/jpeg';
                        artStamp = Date.now();
                    }
                } else if (!data.hasArt) {
                    artBuf = null;
                }
            } catch (_) { }
        }

        setTimeout(poll, 1000);
    });
}

// ── Routes ───────────────────────────────────────────────────────────────────
app.get('/api/current', (_req, res) => {
    res.json({ ...state, artStamp });
});

app.get('/api/art', (_req, res) => {
    if (!artBuf) return res.status(404).send('No art');
    res.setHeader('Content-Type', artMime);
    res.setHeader('Cache-Control', 'no-cache');
    res.send(artBuf);
});

app.use(express.static(WIDGET_DIR));

// ── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
    console.log('');
    console.log('  Music Widget Server  ·  http://localhost:' + PORT);
    console.log('');
    console.log('  OBS Browser Source URLs:');
    console.log('  ┌──────────────────────────────────────────────────────────┐');
    console.log('  │  Small  (400×80)   http://localhost:8888/widget.html?size=sm │');
    console.log('  │  Medium (420×140)  http://localhost:8888/widget.html?size=md │');
    console.log('  │  Large  (520×180)  http://localhost:8888/widget.html?size=lg │');
    console.log('  └──────────────────────────────────────────────────────────┘');
    console.log('');
    console.log('  In OBS: Add Source → Browser → paste the URL above');
    console.log('  Set width/height to match the size you picked.');
    console.log('');
    console.log('  Press Ctrl+C to stop.');
    console.log('');
    poll();
});
