// All calls go to /api on the same origin; nginx forwards them to the API service.
async function loadGreeting() {
  const res = await fetch("/api/greeting");
  const data = await res.json();
  document.getElementById("greeting").textContent = `${data.greeting} (source: ${data.source})`;
}

async function loadNotes() {
  const res = await fetch("/api/notes");
  const notes = await res.json();
  const list = document.getElementById("notes");
  list.replaceChildren(...notes.map((n) => {
    const li = document.createElement("li");
    li.textContent = n.text; // textContent, never innerHTML: user input is never parsed as HTML
    return li;
  }));
}

document.getElementById("note-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const input = document.getElementById("note-text");
  await fetch("/api/notes", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text: input.value }),
  });
  input.value = "";
  loadNotes();
});

loadGreeting();
loadNotes();