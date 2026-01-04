// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

import "./data-confirm.js"

let Hooks = {}

let last_scroll_top_messages = {};
let last_scroll_top_search;
let last_check_search;

Hooks.messageScroll = {
  mounted() {
    let el = this.el
    let channel_id = el.dataset.channel_id;
    let threshold = 5;

    el.addEventListener("scroll", () => {
      const now = Date.now();

      const lastCheck = last_scroll_top_messages[`${channel_id}_time`];

      let last_scroll_top = last_scroll_top_messages[channel_id] || el.scrollTop;
      last_scroll_top_messages[channel_id] = el.scrollTop;

      if (now - lastCheck < 250) return; // Throttle to 250ms

      if ((el.scrollTop <= threshold) && (el.scrollTop <= last_scroll_top)) {
        last_scroll_top_messages[`${channel_id}_time`] = now;
        let first = el.querySelector(".message");
        let last_message_id = first ? first.dataset.message_id : null;
        if (first) this.pushEvent("prev-page", {channel_id: channel_id, last_message_id: last_message_id}, (reply) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (el.scrollTop >= last_scroll_top)) {
        last_scroll_top_messages[`${channel_id}_time`] = now;
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

Hooks.findServerScroll = {
  mounted() {
    let el = this.el
    let threshold = 5;

    el.addEventListener("scroll", () => {
      console.log("TEST");

      const now = Date.now();
      
      const lastCheck = last_check_search;

      let last_scroll_top = last_scroll_top_search || el.scrollTop;
      last_scroll_top_search = el.scrollTop;
      
      if (now - lastCheck < 250) return; // Throttle to 250ms

      if ((el.scrollTop <= threshold) && (el.scrollTop <= last_scroll_top)) {
        last_check_search = now;
        let first = el.querySelector(".search_result");
        let last_server_id = first ? first.dataset.server_id : null;
        if (first) this.pushEventTo("#inner_find_server_form", "prev-page", {last_server_id: last_server_id}, (reply, ref) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (el.scrollTop >= last_scroll_top)) {
        last_check_search = now;
        let items = el.querySelectorAll(".search_result");
        let last = items[items.length - 1];
        let last_server_id = last ? last.dataset.server_id : null;
        if (last) this.pushEventTo("#inner_find_server_form", "next-page", {last_server_id: last_server_id}, (reply, ref) =>
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
      
      const lastCheck = last_check_search;

      let last_scroll_top = last_scroll_top_search || el.scrollTop;
      last_scroll_top_search = el.scrollTop;
      
      if (now - lastCheck < 250) return; // Throttle to 250ms

      if ((el.scrollTop <= threshold) && (el.scrollTop <= last_scroll_top)) {
        last_check_search = now;
        let first = el.querySelector(".search_result");
        let last_message_id = first ? first.dataset.message_id : null;
        if (first) this.pushEvent("search-next-page", {last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      } else if ((el.scrollHeight - el.scrollTop - el.clientHeight <= threshold) && (el.scrollTop >= last_scroll_top)) {
        last_check_search = now;
        let items = el.querySelectorAll(".search_result");
        let last = items[items.length - 1];
        let last_message_id = last ? last.dataset.message_id : null;
        if (last) this.pushEvent("search-prev-page", {last_message_id: last_message_id}, (reply, ref) =>
          console.log(reply)
        );
      }
    })
  }
}

Hooks.updateTime = {
  mounted() {
    this.updateTimestamp();
    this.interval = setInterval(() => this.updateTimestamp(), 60000);
  },
  destroyed() {
    clearInterval(this.interval);
  },
  updateTimestamp() {
    const time = new Date(this.el.getAttribute("datetime"));
    this.el.textContent = this.formatTime(time);
  },
  formatTime(date) {
    const now = new Date();

    const seconds = Math.floor((now - date) / 1000);
    if (seconds < 60) return "just now";

    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;

    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;

    const days = Math.floor(hours / 24);
    if (days < 7) return `${days}d ago`;

    const weeks = Math.floor(days / 7);
    if (weeks < 4) return `${weeks}w ago`;
    
    return date.toLocaleDateString();
  }
}


Hooks.contextMenu = {
  mounted() {
    this.el.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      const menu = document.getElementById(this.el.dataset.context_menu_id);
      if (menu) {
        menu.style.position = "absolute";
        menu.style.display = "block";
        menu.style.left = e.clientX + "px";
        menu.style.top = e.clientY + "px";
      }
    });
    document.addEventListener("click", () => {
      const menu = document.getElementById(this.el.dataset.context_menu_id);
      if (menu) menu.style.display = "none";
    });
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
