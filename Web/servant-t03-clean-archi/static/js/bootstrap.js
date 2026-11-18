const node = document.getElementById("todo-app");

if (window.Elm) {
  window.Elm.Main.init({ node });
} else {
  node.textContent = "The Todo Workspace could not load. Build the frontend and reload.";
}
