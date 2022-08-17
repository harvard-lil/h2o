import { Previewer } from "pagedjs";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("main").forEach((main) => {
    const tmpl = document.querySelector("#casebook-content");
    const css = tmpl.getAttribute("data-stylesheet");
    const paged = new Previewer();
    paged.preview(tmpl.content, [css], main).then((flow) => {
      console.log("Rendered", flow.total, "pages.");
    });
  });
});
