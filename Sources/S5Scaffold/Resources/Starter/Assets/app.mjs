import { api } from './s5/client.mjs';

const form = document.getElementById('note-form');
const input = document.getElementById('note-text');
const list = document.getElementById('notes');
const status = document.getElementById('status');
const submit = document.getElementById('add-note');
let loadingGeneration = 0;
input.maxLength = 280;

function showError(error) {
  status.textContent = error.message || 'Something went wrong. Please try again.';
  status.dataset.error = 'true';
}

async function refresh() {
  const generation = ++loadingGeneration;
  const notes = await api.listNotes();
  if (generation !== loadingGeneration) return;
  list.replaceChildren(...notes.map(renderNote));
  status.dataset.error = 'false';
  status.textContent = notes.length
    ? `${notes.length} ${notes.length === 1 ? 'note' : 'notes'} · newest first${notes.length === 100 ? ' · showing latest 100' : ''}`
    : 'Your notebook is empty. Add the first idea above.';
}

function renderNote(note) {
  const item = document.createElement('li');
  item.className = note.completed ? 'note completed' : 'note';
  const checkbox = document.createElement('input');
  checkbox.type = 'checkbox';
  checkbox.checked = note.completed;
  checkbox.setAttribute('aria-label', `Mark ${note.text} ${note.completed ? 'incomplete' : 'complete'}`);
  const text = document.createElement('span');
  text.textContent = note.text;
  const remove = document.createElement('button');
  remove.type = 'button';
  remove.className = 'remove';
  remove.textContent = 'Delete';
  remove.setAttribute('aria-label', `Delete ${note.text}`);
  checkbox.addEventListener('change', async () => {
    checkbox.disabled = true;
    remove.disabled = true;
    try {
      await api.setCompleted({ id: note.id, completed: checkbox.checked });
      await refresh();
    } catch (error) {
      checkbox.checked = note.completed;
      showError(error);
    } finally { checkbox.disabled = remove.disabled = false; }
  });
  remove.addEventListener('click', async () => {
    checkbox.disabled = remove.disabled = true;
    try { await api.deleteNote({ id: note.id }); await refresh(); }
    catch (error) { showError(error); }
    finally { checkbox.disabled = remove.disabled = false; }
  });
  item.append(checkbox, text, remove);
  return item;
}

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (submit.disabled) return;
  const text = input.value.trim();
  if (!text) { input.focus(); return; }
  submit.disabled = true;
  try {
    await api.createNote({ text });
    input.value = '';
    await refresh();
    input.focus();
  } catch (error) { showError(error); }
  finally { submit.disabled = false; }
});

refresh().catch(showError);
