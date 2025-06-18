defmodule ChatServerWeb.CustomComponents do
  use Phoenix.Component
  use ChatServerWeb, :verified_routes
  use Gettext, backend: ChatServerWeb.Gettext

  import ChatServerWeb.CoreComponents

  alias Phoenix.LiveView.JS

@doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        <header>Title</header>
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :hide_event, :string, required: true
  attr :target, :any, required: true
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true
  def raw_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50"
    >
      <div id={"#{@id}-bg"} class="bg-zinc-50/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.push(@hide_event)}
              phx-key="escape"
              phx-target={@target}
              phx-click-away={JS.push(@hide_event)}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div :if={@header} class="flex shrink-0 items-center pb-4 text-xl font-medium text-slate-800">
                {render_slot(@header)}
              </div>
              {render_slot(@inner_block)}
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
