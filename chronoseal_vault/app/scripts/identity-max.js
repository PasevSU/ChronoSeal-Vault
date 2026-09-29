/* PasevSU ChronoSeal Vault — Identity MAX extension
 * Purpose: restore a real Name field and collect a rich identity profile while
 * keeping OpenPGP-native data (UIDs / signature notations) separate from local metadata.
 * Designed for OpenPGP.js 6.3.1.
 */
(() => {
  'use strict';

  const PROFILE_KEY = 'pasevsu.identityMax.draft.v1';
  const PROFILE_BY_FPR = 'pasevsu.identityMax.byFingerprint.v1';
  const enc = new TextEncoder();
  let originalGenerateKey = null;
  let originalReformatKey = null;

  const $ = id => document.getElementById(id);
  const val = id => ($(id)?.value || '').trim();
  const checked = id => !!$(id)?.checked;
  const lines = s => String(s || '').split(/[\r\n,;]+/).map(x => x.trim()).filter(Boolean);
  const uniq = xs => [...new Set(xs.filter(Boolean))];
  const safeJson = (s, fallback) => { try { return JSON.parse(s); } catch { return fallback; } };

  function profileFromForm() {
    const primaryEmail = val('keyEmail');
    const extraEmails = lines(val('keyAdditionalEmails'));
    const phones = lines(val('keyPhones'));
    const urls = lines(val('keyUrls'));
    const customNotations = lines(val('keyCustomNotations')).map(line => {
      const i = line.indexOf('=');
      return i > 0 ? { name: line.slice(0, i).trim(), value: line.slice(i + 1).trim() } : null;
    }).filter(Boolean);
    return {
      schema: 'pasevsu-identity-profile-v1',
      name: val('keyName'),
      givenName: val('keyGivenName'),
      middleName: val('keyMiddleName'),
      familyName: val('keyFamilyName'),
      prefix: val('keyNamePrefix'),
      suffix: val('keyNameSuffix'),
      comment: val('keyComment'),
      primaryEmail,
      emails: uniq([primaryEmail, ...extraEmails]),
      organization: val('keyOrganization'),
      organizationalUnit: val('keyOrgUnit'),
      title: val('keyTitle'),
      role: val('keyRole'),
      phones,
      urls,
      street: val('keyStreet'),
      city: val('keyCity'),
      region: val('keyRegion'),
      postalCode: val('keyPostalCode'),
      country: val('keyCountry'),
      caseId: val('keyCaseId'),
      evidenceId: val('keyEvidenceId'),
      operatorId: val('keyOperatorId'),
      tags: lines(val('keyTags')),
      notes: val('keyProfileNotes'),
      notationDomain: val('keyNotationDomain').toLowerCase(),
      embedNotations: checked('keyEmbedNotations'),
      customNotations,
      updatedAtUtc: new Date().toISOString()
    };
  }

  function displayName(p) {
    if (p.name) return p.name;
    return [p.prefix, p.givenName, p.middleName, p.familyName, p.suffix].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
  }

  function uidName(p) {
    const name = displayName(p);
    const c = p.comment;
    return c ? `${name} (${c})` : name;
  }

  function buildUserIDs(p) {
    const name = uidName(p);
    if (!name) throw new Error('Identity MAX: Name is required.');
    const emails = p.emails.length ? p.emails : [''];
    return emails.map(email => email ? { name, email } : { name });
  }

  function validNotationDomain(domain) {
    return /^(?=.{3,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i.test(domain || '');
  }

  function buildSignatureNotations(p) {
    if (!p.embedNotations) return [];
    if (!validNotationDomain(p.notationDomain)) {
      throw new Error('Identity MAX: a valid DNS notation domain is required before embedding signed notations.');
    }
    const d = p.notationDomain;
    const out = [];
    const add = (tag, value) => {
      if (!value) return;
      out.push({ name: `${tag}@${d}`, value: enc.encode(String(value)), humanReadable: true, critical: false });
    };
    add('organization', p.organization);
    add('organizational-unit', p.organizationalUnit);
    add('title', p.title);
    add('role', p.role);
    p.phones.forEach((v, i) => add(`phone-${i + 1}`, v));
    p.urls.forEach((v, i) => add(`url-${i + 1}`, v));
    add('street', p.street);
    add('city', p.city);
    add('region', p.region);
    add('postal-code', p.postalCode);
    add('country', p.country);
    add('case-id', p.caseId);
    add('evidence-id', p.evidenceId);
    add('operator-id', p.operatorId);
    if (p.tags.length) add('tags', p.tags.join(', '));
    for (const n of p.customNotations) {
      const name = n.name.includes('@') ? n.name : `${n.name}@${d}`;
      out.push({ name, value: enc.encode(n.value), humanReadable: true, critical: false });
    }
    return out;
  }

  function saveDraft() {
    try { localStorage.setItem(PROFILE_KEY, JSON.stringify(profileFromForm())); } catch {}
  }

  function loadDraft() {
    try { return safeJson(localStorage.getItem(PROFILE_KEY), null); } catch { return null; }
  }

  function setv(id, value) { const e = $(id); if (e && value != null) e.value = value; }
  function applyProfile(p) {
    if (!p) return;
    setv('keyName', p.name);
    setv('keyGivenName', p.givenName);
    setv('keyMiddleName', p.middleName);
    setv('keyFamilyName', p.familyName);
    setv('keyNamePrefix', p.prefix);
    setv('keyNameSuffix', p.suffix);
    setv('keyComment', p.comment);
    setv('keyEmail', p.primaryEmail || p.emails?.[0]);
    setv('keyAdditionalEmails', (p.emails || []).filter(x => x && x !== (p.primaryEmail || p.emails?.[0])).join('\n'));
    setv('keyOrganization', p.organization);
    setv('keyOrgUnit', p.organizationalUnit);
    setv('keyTitle', p.title);
    setv('keyRole', p.role);
    setv('keyPhones', (p.phones || []).join('\n'));
    setv('keyUrls', (p.urls || []).join('\n'));
    setv('keyStreet', p.street);
    setv('keyCity', p.city);
    setv('keyRegion', p.region);
    setv('keyPostalCode', p.postalCode);
    setv('keyCountry', p.country);
    setv('keyCaseId', p.caseId);
    setv('keyEvidenceId', p.evidenceId);
    setv('keyOperatorId', p.operatorId);
    setv('keyTags', (p.tags || []).join(', '));
    setv('keyProfileNotes', p.notes);
    setv('keyNotationDomain', p.notationDomain);
    const cb = $('keyEmbedNotations'); if (cb) cb.checked = !!p.embedNotations;
    setv('keyCustomNotations', (p.customNotations || []).map(x => `${x.name}=${x.value}`).join('\n'));
  }

  function parseVCard(text) {
    const raw = String(text || '').replace(/\r?\n[ \t]/g, '');
    const rows = raw.split(/\r?\n/);
    const getAll = key => rows.filter(r => r.toUpperCase().startsWith(key + ':') || r.toUpperCase().startsWith(key + ';')).map(r => r.slice(r.indexOf(':') + 1));
    const first = key => getAll(key)[0] || '';
    const unescape = s => String(s || '').replace(/\\n/gi, '\n').replace(/\\,/g, ',').replace(/\\;/g, ';').replace(/\\\\/g, '\\');
    const n = unescape(first('N')).split(';');
    const org = unescape(first('ORG')).split(';');
    const adr = unescape(first('ADR')).split(';');
    const emails = uniq(getAll('EMAIL').map(unescape));
    return {
      schema: 'pasevsu-identity-profile-v1',
      name: unescape(first('FN')),
      familyName: n[0] || '', givenName: n[1] || '', middleName: n[2] || '', prefix: n[3] || '', suffix: n[4] || '',
      comment: unescape(first('NOTE')),
      primaryEmail: emails[0] || '', emails,
      organization: org[0] || '', organizationalUnit: org.slice(1).filter(Boolean).join(' / '),
      title: unescape(first('TITLE')), role: unescape(first('ROLE')),
      phones: uniq(getAll('TEL').map(unescape)), urls: uniq(getAll('URL').map(unescape)),
      street: adr[2] || '', city: adr[3] || '', region: adr[4] || '', postalCode: adr[5] || '', country: adr[6] || '',
      caseId: '', evidenceId: '', operatorId: '', tags: [], notes: '', notationDomain: '', embedNotations: false, customNotations: []
    };
  }

  function downloadJson(name, obj) {
    const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  function installUi() {
    const password = $('keyPassword');
    if (!password || $('identityMaxPanel')) return;
    const anchor = password.closest('div');
    const panel = document.createElement('div');
    panel.id = 'identityMaxPanel';
    panel.className = 'md:col-span-2 identity-max-panel';
    panel.innerHTML = `
      <fieldset class="identity-max-fieldset">
        <legend>Identity Profile · maximum information</legend>
        <p class="identity-max-note">Name and email(s) become OpenPGP User IDs. Other fields are preserved as local profile metadata; when enabled, selected fields are also embedded as signed OpenPGP notations.</p>
        <div class="identity-max-grid">
          <label>Full Name *<input id="keyName" class="input" type="text" autocomplete="name" required placeholder="Full legal / display name"></label>
          <label>Given name<input id="keyGivenName" class="input" type="text" autocomplete="given-name"></label>
          <label>Middle name<input id="keyMiddleName" class="input" type="text" autocomplete="additional-name"></label>
          <label>Family name<input id="keyFamilyName" class="input" type="text" autocomplete="family-name"></label>
          <label>Prefix<input id="keyNamePrefix" class="input" type="text" placeholder="Dr., Ing., ..."></label>
          <label>Suffix<input id="keyNameSuffix" class="input" type="text" placeholder="Jr., MSc, ..."></label>
          <label>Organization<input id="keyOrganization" class="input" type="text" autocomplete="organization"></label>
          <label>Organizational unit<input id="keyOrgUnit" class="input" type="text" placeholder="Department / Unit"></label>
          <label>Title<input id="keyTitle" class="input" type="text" autocomplete="organization-title"></label>
          <label>Role<input id="keyRole" class="input" type="text" placeholder="Operator / Administrator / ..."></label>
          <label class="identity-max-wide">Additional emails<textarea id="keyAdditionalEmails" class="textarea" placeholder="one address per line"></textarea></label>
          <label>Phones<textarea id="keyPhones" class="textarea" placeholder="one number per line"></textarea></label>
          <label>URLs<textarea id="keyUrls" class="textarea" placeholder="one URL per line"></textarea></label>
          <label class="identity-max-wide">Street / address<input id="keyStreet" class="input" type="text" autocomplete="street-address"></label>
          <label>City<input id="keyCity" class="input" type="text" autocomplete="address-level2"></label>
          <label>Region / State<input id="keyRegion" class="input" type="text" autocomplete="address-level1"></label>
          <label>Postal code<input id="keyPostalCode" class="input" type="text" autocomplete="postal-code"></label>
          <label>Country<input id="keyCountry" class="input" type="text" autocomplete="country-name"></label>
          <label>Case ID<input id="keyCaseId" class="input" type="text"></label>
          <label>Evidence ID<input id="keyEvidenceId" class="input" type="text"></label>
          <label>Operator ID<input id="keyOperatorId" class="input" type="text"></label>
          <label>Tags<input id="keyTags" class="input" type="text" placeholder="personal, signing, evidence"></label>
          <label class="identity-max-wide">Profile notes<textarea id="keyProfileNotes" class="textarea"></textarea></label>
        </div>
        <details class="identity-max-advanced">
          <summary>Signed notation options / advanced</summary>
          <label>Notation namespace DNS domain<input id="keyNotationDomain" class="input" type="text" placeholder="example.org"></label>
          <label class="identity-max-check"><input id="keyEmbedNotations" type="checkbox"> Embed profile fields as signed OpenPGP notations</label>
          <label>Custom notations<textarea id="keyCustomNotations" class="textarea" placeholder="tag=value or tag@example.org=value"></textarea></label>
          <p class="identity-max-note">Use a DNS domain you control. RFC 9580 user-namespace notation names use tag@domain.</p>
        </details>
        <div class="identity-max-actions">
          <label class="btn btn-muted" role="button">Import vCard (.vcf)<input id="identityVcfInput" type="file" accept=".vcf,text/vcard,text/x-vcard" hidden></label>
          <label class="btn btn-muted" role="button">Import profile JSON<input id="identityJsonInput" type="file" accept="application/json,.json" hidden></label>
          <button id="identityExportButton" class="btn btn-muted" type="button">Export profile JSON</button>
          <button id="identitySaveDraftButton" class="btn btn-muted" type="button">Save profile draft</button>
          <button id="identityLoadDraftButton" class="btn btn-muted" type="button">Load profile draft</button>
        </div>
      </fieldset>`;
    anchor.parentNode.insertBefore(panel, anchor);

    const vcf = $('identityVcfInput');
    vcf?.addEventListener('change', async () => { const f = vcf.files?.[0]; if (f) { applyProfile(parseVCard(await f.text())); saveDraft(); } });
    const js = $('identityJsonInput');
    js?.addEventListener('change', async () => { const f = js.files?.[0]; if (f) { applyProfile(JSON.parse(await f.text())); saveDraft(); } });
    $('identityExportButton')?.addEventListener('click', () => downloadJson('pasevsu-identity-profile.json', profileFromForm()));
    $('identitySaveDraftButton')?.addEventListener('click', saveDraft);
    $('identityLoadDraftButton')?.addEventListener('click', () => applyProfile(loadDraft()));
    panel.addEventListener('input', saveDraft);
    panel.addEventListener('change', saveDraft);
    applyProfile(loadDraft());
  }

  async function saveProfileByFingerprint(result, p) {
    try {
      const armored = typeof result?.publicKey === 'string' ? result.publicKey : null;
      if (!armored || !window.openpgp?.readKey) return;
      const key = await window.openpgp.readKey({ armoredKey: armored });
      const fpr = String(key.getFingerprint()).toUpperCase();
      const db = safeJson(localStorage.getItem(PROFILE_BY_FPR), {});
      db[fpr] = { ...p, fingerprint: fpr, boundAtUtc: new Date().toISOString() };
      localStorage.setItem(PROFILE_BY_FPR, JSON.stringify(db));
      window.dispatchEvent(new CustomEvent('pasevsu:identity-profile-bound', { detail: { fingerprint: fpr, profile: db[fpr] } }));
    } catch (e) { console.warn('[Identity MAX] profile fingerprint binding failed:', e); }
  }

  function installOpenPgpWrapper() {
    if (!window.openpgp || window.openpgp.__pasevsuIdentityMaxWrapped) return;
    originalGenerateKey = window.openpgp.generateKey?.bind(window.openpgp);
    originalReformatKey = window.openpgp.reformatKey?.bind(window.openpgp);
    if (originalGenerateKey) {
      window.openpgp.generateKey = async function(options = {}) {
        const p = profileFromForm();
        const name = displayName(p);
        if (!name) return originalGenerateKey(options); // non-UI/internal generation remains untouched
        const patched = { ...options, userIDs: buildUserIDs(p) };
        const notations = buildSignatureNotations(p);
        if (notations.length) patched.signatureNotations = [...(options.signatureNotations || []), ...notations];
        const result = await originalGenerateKey(patched);
        await saveProfileByFingerprint(result, p);
        return result;
      };
    }
    if (originalReformatKey) {
      window.openpgp.reformatKey = async function(options = {}) {
        const p = profileFromForm();
        const name = displayName(p);
        if (!name) return originalReformatKey(options);
        const patched = { ...options, userIDs: buildUserIDs(p) };
        const notations = buildSignatureNotations(p);
        if (notations.length) patched.signatureNotations = [...(options.signatureNotations || []), ...notations];
        return originalReformatKey(patched);
      };
    }
    Object.defineProperty(window.openpgp, '__pasevsuIdentityMaxWrapped', { value: true, configurable: false });
  }

  function init() {
    installUi();
    installOpenPgpWrapper();
    // Existing v2.1.1 incorrectly uses keyComment as the UID name. Keep the old
    // field for compatibility, but Identity MAX always supplies the real Name.
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
