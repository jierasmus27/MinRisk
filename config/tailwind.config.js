const defaultTheme = require("tailwindcss/defaultTheme")

const stitchColors = {
  "on-surface-variant": "#44474e",
  surface: "#f8f9fa",
  "surface-container-lowest": "#ffffff",
  "surface-container": "#edeeef",
  primary: "#000a1e",
  "on-primary-container": "#708ab5",
  "tertiary-fixed": "#d7e2ff",
  "surface-variant": "#e1e3e4",
  "on-error": "#ffffff",
  "on-primary-fixed-variant": "#2d476f",
  outline: "#74777f",
  "on-primary-fixed": "#001b3d",
  background: "#f8f9fa",
  "secondary-fixed": "#ffdcc3",
  "inverse-on-surface": "#f0f1f2",
  "on-surface": "#191c1d",
  "on-background": "#191c1d",
  "inverse-surface": "#2e3132",
  error: "#ba1a1a",
  "surface-container-high": "#e7e8e9",
  "on-secondary": "#ffffff",
  tertiary: "#000a20",
  "primary-fixed-dim": "#aec7f6",
  "surface-container-low": "#f3f4f5",
  "surface-bright": "#f8f9fa",
  "on-tertiary-fixed": "#001a40",
  "inverse-primary": "#aec7f6",
  "on-primary": "#ffffff",
  "on-tertiary": "#ffffff",
  secondary: "#904d00",
  "on-tertiary-container": "#4e87e7",
  "on-error-container": "#93000a",
  "tertiary-container": "#00204b",
  "primary-container": "#002147",
  "surface-dim": "#d9dadb",
  "on-tertiary-fixed-variant": "#004491",
  "secondary-fixed-dim": "#ffb77d",
  "secondary-container": "#fd8b00",
  "outline-variant": "#c4c6cf",
  "on-secondary-fixed-variant": "#6e3900",
  "error-container": "#ffdad6",
  "surface-tint": "#465f88",
  "tertiary-fixed-dim": "#acc7ff",
  "on-secondary-fixed": "#2f1500",
  "surface-container-highest": "#e1e3e4",
  "primary-fixed": "#d6e3ff",
  "on-secondary-container": "#603100"
}

module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}"
  ],
  theme: {
    extend: {
      colors: stitchColors,
      fontFamily: {
        "tabular-numeric": [ "Inter", ...defaultTheme.fontFamily.sans ],
        "code-data": [ "JetBrains Mono", ...defaultTheme.fontFamily.mono ],
        "headline-lg": [ "Hanken Grotesk", ...defaultTheme.fontFamily.sans ],
        "body-md": [ "Inter", ...defaultTheme.fontFamily.sans ],
        "body-lg": [ "Inter", ...defaultTheme.fontFamily.sans ],
        "label-caps": [ "Inter", ...defaultTheme.fontFamily.sans ],
        "headline-md": [ "Hanken Grotesk", ...defaultTheme.fontFamily.sans ]
      },
      fontSize: {
        "tabular-numeric": [ "14px", { lineHeight: "20px", fontWeight: "500" } ],
        "code-data": [ "12px", { lineHeight: "16px", fontWeight: "400" } ],
        "headline-lg": [ "28px", { lineHeight: "34px", letterSpacing: "-0.02em", fontWeight: "600" } ],
        "body-md": [ "14px", { lineHeight: "20px", fontWeight: "400" } ],
        "body-lg": [ "16px", { lineHeight: "24px", fontWeight: "400" } ],
        "label-caps": [ "11px", { lineHeight: "16px", letterSpacing: "0.05em", fontWeight: "700" } ],
        "headline-md": [ "20px", { lineHeight: "28px", fontWeight: "600" } ]
      }
    }
  },
  plugins: []
}
