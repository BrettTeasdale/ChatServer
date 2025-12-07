// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"


let Hooks = {}

let last_scroll_top_messages = {};
let last_scroll_top_search_history;
let last_check_search_history;

Hooks.messageScroll = {
  mounted() {

    console.log("TEST");
    let el = this.el
    let channel_id = el.dataset.channel_id;
    let threshold = 5;

    el.addEventListener("scroll", () => {
      const now = Date.now();

      const lastCheck = last_scroll_top_messages[`${channel_id}_time`];
      console.log(now, "now", lastCheck, "lastcheck", now - lastCheck, "diff");

      let last_scroll_top = last_scroll_top_messages[channel_id] || el.scrollTop;
      last_scroll_top_messages[channel_id] = el.scrollTop;
      
      console.log(el.clientHeight, "test", el.scrollTop, "scroll", el.scrollHeight - el.scrollTop - el.clientHeight, "mathed", el.scrollTop >= last_scroll_top, "direction");

      if (now - lastCheck < 250) return; // Throttle to 250ms

      if ((el.scrollTop <= threshold) && (el.scrollTop <= last_scroll_top)) {
        last_scroll_top_messages[`${channel_id}_time`] = now;
        console.log("REACHED TOP");
        let first = el.querySelector(".message");
        let last_message_id = first ? first.dataset.message_id : null;
        if (first) this.pushEvent("prev-page", {channel_id: channel_id, last_message_id: last_message_id}, (reply) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (el.scrollTop >= last_scroll_top)) {
        last_scroll_top_messages[`${channel_id}_time`] = now;
        console.log("REACHED BOTTOM");
        let items = el.querySelectorAll(".message");
        let last = items[items.length - 1];
        let last_message_id = last ? last.dataset.message_id : null;
        if (last) this.pushEvent("next-page", {channel_id: channel_id, last_message_id: last_message_id}, (reply) =>
          console.log(reply)
        );
      }

    })
  }
}

Hooks.searchHistoryScroll = {
  mounted() {
    let el = this.el
    let threshold = 5;

    el.addEventListener("scroll", () => {
      const now = Date.now();
      
      const lastCheck = last_check_search_history;
      console.log(now, "now", lastCheck, "lastcheck", now - lastCheck, "diff");

      let last_scroll_top = last_scroll_top_search_history || el.scrollTop;
      last_scroll_top_search_history = el.scrollTop;

      console.log(el.clientHeight, "test", el.scrollTop, "scroll", el.scrollHeight - el.scrollTop - el.clientHeight, "mathed", el.scrollTop >= last_scroll_top, "direction");
      
      if (now - lastCheck < 250) return; // Throttle to 250ms
      console.log("CHECKING SEARCH SCROLL");

      if ((el.scrollTop <= threshold) && (el.scrollTop <= last_scroll_top)) {
        last_check_search_history = now;
        console.log("REACHED TOP SEARCH");
        let first = el.querySelector(".message");
        let last_message_id = first ? first.dataset.message_id : null;
        if (first) this.pushEvent("prev-page", {last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (el.scrollTop >= last_scroll_top)) {

        last_check_search_history = now;
        console.log("REACHED BOTTOM SEARCH");
        let items = el.querySelectorAll(".message");
        let last = items[items.length - 1];
        let last_message_id = last ? last.dataset.message_id : null;
        if (last) this.pushEvent("next-page", {last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      }
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
