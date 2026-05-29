module ApplicationHelper
  GOOGLE_OAUTH_BUTTON_CLASSES = [
    "inline-flex h-10 min-w-[184px] items-center justify-center gap-[10px]",
    "rounded-full border border-[#747775] bg-white px-3",
    "font-['Roboto','Arial',sans-serif] text-sm font-medium leading-5 text-[#1f1f1f]",
    "shadow-sm transition-colors duration-200",
    "hover:bg-[#f8fafd] focus:outline-none focus:ring-2 focus:ring-[#1a73e8] focus:ring-offset-2",
    "active:bg-[#f1f3f4]"
  ].join(" ").freeze

  def google_oauth_button_to(label, path, button_class: nil, form_class: nil)
    button_to path,
      method: :post,
      class: class_list(GOOGLE_OAUTH_BUTTON_CLASSES, button_class),
      form: { class: form_class } do
        google_oauth_button_content(label)
      end
  end

  def google_oauth_link_to(label, path, link_class: nil)
    link_to path, class: class_list(GOOGLE_OAUTH_BUTTON_CLASSES, link_class) do
      google_oauth_button_content(label)
    end
  end

  private

  def class_list(*classes)
    classes.compact_blank.join(" ")
  end

  def google_oauth_button_content(label)
    safe_join([google_g_icon, tag.span(label)])
  end

  def google_g_icon
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 18 18",
      class: "h-[18px] w-[18px] shrink-0",
      aria: { hidden: true },
      focusable: "false"
    ) do
      safe_join([
        tag.path(fill: "#4285F4", d: "M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.91c1.7-1.57 2.69-3.88 2.69-6.62z"),
        tag.path(fill: "#34A853", d: "M9 18c2.43 0 4.47-.8 5.96-2.18l-2.91-2.26c-.81.54-1.84.86-3.05.86-2.35 0-4.33-1.58-5.04-3.71H.96v2.33A9 9 0 0 0 9 18z"),
        tag.path(fill: "#FBBC05", d: "M3.96 10.71a5.41 5.41 0 0 1 0-3.42V4.96H.96a9 9 0 0 0 0 8.08l3-2.33z"),
        tag.path(fill: "#EA4335", d: "M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58C13.46.9 11.42 0 9 0A9 9 0 0 0 .96 4.96l3 2.33C4.67 5.16 6.65 3.58 9 3.58z")
      ])
    end
  end
end
