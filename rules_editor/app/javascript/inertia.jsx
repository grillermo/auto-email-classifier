import { createInertiaApp } from "@inertiajs/react";
import { createRoot } from "react-dom/client";
import RulesEditPage from "./pages/Rules/Edit.jsx";
import RulesIndexPage from "./pages/Rules/Index.jsx";
import RulesShowPage from "./pages/Rules/Show.jsx";

const pages = {
  "Rules/Edit": RulesEditPage,
  "Rules/Index": RulesIndexPage,
  "Rules/Show": RulesShowPage,
};

void createInertiaApp({
  resolve: (name) => {
    const page = pages[name];

    if (!page) {
      throw new Error(`Missing Inertia page component: ${name}`);
    }

    return page;
  },
  setup({ el, App, props }) {
    createRoot(el).render(<App {...props} />);
  },
}).catch((error) => {
  if (document.getElementById("app")) {
    throw error;
  }
});
