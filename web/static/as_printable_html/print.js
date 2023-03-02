import { Previewer } from "./pagedjs.js";

console.log("Starting pagination");

const paged = new Previewer();

paged
  .preview(
    document.querySelector("main"),
    [window.css],
    document.querySelector("#pdf-output")
  )
  .then((flow) => {
    console.log("Rendered", flow.total, "pages.");
    document.querySelector("main").remove();
    document.querySelector("#pdf-output").style.visibility = "visible";
  });
