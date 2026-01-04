// data-confirm.js

// Store confirmation state since modals don't block execution like window.confirm()
const resolvedAttr = "data-confirm-resolved";
const getEl = (suffix) => document.getElementById(`data-confirm-${suffix}`);
let target = null;

document.body.addEventListener(
  "phoenix.link.click",
  function (e) {
    e.stopPropagation();
    const message = e.target.getAttribute("data-confirm");
    if (!message) {
      return;
    }

    target = e.target;

    if (e.target?.hasAttribute(resolvedAttr)) {
      e.target.removeAttribute(resolvedAttr);
      return;
    }

    e.preventDefault();
    e.target?.setAttribute(resolvedAttr, "");
    populateModal(e.target.dataset);

    console.log(getEl("modal").dataset.show);

    window.liveSocket.execJS(getEl("modal"), getEl("modal").dataset.show);
  },
  false,
);

window.addEventListener("data-confirm:confirm", () => {
  window.liveSocket.execJS(getEl("modal"), getEl("modal").dataset.hide);
  target?.click();
  target = null;
});

window.addEventListener("data-confirm:cancel", () => {
  window.liveSocket.execJS(getEl("modal"), getEl("modal").dataset.hide);
  target?.removeAttribute(resolvedAttr);
  target = null;
});

function populateModal(dataset) {
  const icon = dataset.confirmIcon;
  getEl("icon").className = getEl("icon").dataset.class;
  getEl("icon").classList.toggle("hidden", !icon);
  if (icon) {
    getEl("icon").classList.add(icon);
  }

  const variant = dataset.confirmVariant || "primary";
  ["primary", "danger"].forEach((v) =>
    getEl(`button-${v}`).classList.toggle("hidden", v !== variant),
  );

  getEl("title").innerHTML = dataset.confirmTitle || "Are you sure?";
  getEl("message").innerHTML = dataset.confirm;
  getEl(`button-${variant}`).innerHTML = dataset.confirmButton || "Yes";
}
