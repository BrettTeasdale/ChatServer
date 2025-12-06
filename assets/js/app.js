// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"


let Hooks = {}

let last_scroll_top = {};

Hooks.messageScroll = {
  mounted() {

    console.log("TEST");
    let el = this.el
    let channel_id = el.dataset.channel_id;
    let threshold = 5;

    el.addEventListener("scroll", () => {
      const now = Date.now();
      const lastCheck = last_scroll_top[`${channel_id}_time`] || 0;
      
      if (now - lastCheck < 500) return; // Throttle to 500ms
      last_scroll_top[`${channel_id}_time`] = now;

      if ((el.scrollTop <= threshold) && (last_scroll_top[channel_id] > el.scrollTop)) {
        console.log("REACHED TOP");
        let first = el.querySelector(".message");
        let last_message_id = first ? first.dataset.message_id : null;
        if (first) this.pushEvent("prev-page", {channel_id: channel_id, last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (last_scroll_top[channel_id] < el.scrollTop)) {
        console.log("REACHED BOTTOM");
        let items = el.querySelectorAll(".message");
        let last = items[items.length - 1];
        let last_message_id = last ? last.dataset.message_id : null;
        if (last) this.pushEvent("next-page", {channel_id: channel_id, last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      }

      last_scroll_top[channel_id] = el.scrollTop;
    })
  }
}

export default Hooks

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
