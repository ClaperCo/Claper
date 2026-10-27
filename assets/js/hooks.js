// LiveView hooks for client-side functionality

import WordCloud from "./word_cloud.mjs";

// Flash alerts also appear in plain HTTP layouts, outside the LiveView hook lifecycle.
const alertSelector = "[data-auto-dismiss-alert]";
const alertTimers = new WeakMap();

function updateAlert(alert) {
  window.clearTimeout(alertTimers.get(alert));
  alert.style.removeProperty("display");

  if (alert.hasAttribute("data-auto-dismiss-alert")) {
    alertTimers.set(alert, window.setTimeout(() => {
      if (alert.isConnected && alert.hasAttribute("data-auto-dismiss-alert")) {
        alert.style.display = "none";
      }
    }, 4000));
  }
}

function initializeAlerts() {
  document.querySelectorAll(alertSelector).forEach(updateAlert);

  new MutationObserver((mutations) => {
    const changedAlerts = new Set();

    for (const mutation of mutations) {
      if (mutation.type === "attributes") {
        changedAlerts.add(mutation.target);
      } else if (mutation.type === "characterData") {
        const alert = mutation.target.parentElement?.closest(alertSelector);
        if (alert) changedAlerts.add(alert);
      } else {
        if (mutation.addedNodes.length) {
          const alert = mutation.target.closest?.(alertSelector);
          if (alert) changedAlerts.add(alert);
        }

        for (const node of mutation.addedNodes) {
          if (node.nodeType !== 1) continue;
          if (node.matches(alertSelector)) changedAlerts.add(node);
          node.querySelectorAll(alertSelector).forEach((alert) => changedAlerts.add(alert));
        }
      }
    }

    for (const alert of changedAlerts) {
      if (alert.isConnected) updateAlert(alert);
    }
  }).observe(document.body, {
    childList: true,
    characterData: true,
    attributes: true,
    attributeFilter: ["data-auto-dismiss-alert"],
    subtree: true,
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initializeAlerts, { once: true });
} else {
  initializeAlerts();
}

const Hooks = {
  // Hook for handling CSV downloads from LiveView
  CSVDownloader: {
    mounted() {
      this.handleEvent("download_csv", ({ filename, content }) => {
        // Create a Blob with the CSV content
        const blob = new Blob([content], { type: "text/csv" });
        
        // Create a temporary URL for the Blob
        const url = window.URL.createObjectURL(blob);
        
        // Create a temporary link element
        const link = document.createElement("a");
        link.href = url;
        link.setAttribute("download", filename);
        
        // Append the link to the document body
        document.body.appendChild(link);
        
        // Trigger the download
        link.click();
        
        // Clean up
        window.URL.revokeObjectURL(url);
        document.body.removeChild(link);
      });
    }
  },
  
  // Hook for User Growth Chart
  UserGrowthChart: {
    mounted() {
      // Import Chart.js dynamically
      import("chart.js/auto").then(({ default: Chart }) => {
        const ctx = this.el.getContext("2d");
        const labels = JSON.parse(this.el.dataset.labels);
        const values = JSON.parse(this.el.dataset.values);
        
        this.chart = new Chart(ctx, {
          type: "line",
          data: {
            labels: labels,
            datasets: [{
              label: "New Users",
              data: values,
              borderColor: "#111827",
              backgroundColor: "rgba(17, 24, 39, 0.05)",
              borderWidth: 2,
              tension: 0.4,
              fill: true,
              pointRadius: 0,
              pointHoverRadius: 0,
              pointBackgroundColor: "transparent",
              pointBorderColor: "transparent"
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
              intersect: false,
              mode: 'index'
            },
            plugins: {
              legend: {
                display: false
              },
              tooltip: {
                enabled: true,
                backgroundColor: "rgba(17, 24, 39, 0.9)",
                titleColor: "#fff",
                bodyColor: "#fff",
                borderColor: "#111827",
                borderWidth: 1,
                cornerRadius: 4,
                displayColors: false,
                padding: 8,
                titleFont: {
                  size: 12
                },
                bodyFont: {
                  size: 14,
                  weight: 'bold'
                },
                callbacks: {
                  label: function(context) {
                    return context.parsed.y + ' users';
                  }
                }
              }
            },
            scales: {
              x: {
                display: false
              },
              y: {
                display: false
              }
            }
          }
        });
      });
    },
    
    destroyed() {
      if (this.chart) {
        this.chart.destroy();
      }
    }
  },
  
  // Hook for persisting view mode preference to localStorage
  ViewModePreference: {
    mounted() {
      const savedMode = localStorage.getItem("claper_event_list_view_mode");
      if (savedMode && (savedMode === "grid" || savedMode === "list")) {
        this.pushEvent("restore-view-mode", { view: savedMode });
      }

      this.handleEvent("save-view-mode", ({ view }) => {
        localStorage.setItem("claper_event_list_view_mode", view);
      });
    }
  },

  // Hook for Event Creation Chart
  EventCreationChart: {
    mounted() {
      // Import Chart.js dynamically
      import("chart.js/auto").then(({ default: Chart }) => {
        const ctx = this.el.getContext("2d");
        const labels = JSON.parse(this.el.dataset.labels);
        const values = JSON.parse(this.el.dataset.values);
        
        this.chart = new Chart(ctx, {
          type: "line",
          data: {
            labels: labels,
            datasets: [{
              label: "New Events",
              data: values,
              borderColor: "#111827",
              backgroundColor: "rgba(17, 24, 39, 0.05)",
              borderWidth: 2,
              tension: 0.4,
              fill: true,
              pointRadius: 0,
              pointHoverRadius: 0,
              pointBackgroundColor: "transparent",
              pointBorderColor: "transparent"
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
              intersect: false,
              mode: 'index'
            },
            plugins: {
              legend: {
                display: false
              },
              tooltip: {
                enabled: true,
                backgroundColor: "rgba(17, 24, 39, 0.9)",
                titleColor: "#fff",
                bodyColor: "#fff",
                borderColor: "#111827",
                borderWidth: 1,
                cornerRadius: 4,
                displayColors: false,
                padding: 8,
                titleFont: {
                  size: 12
                },
                bodyFont: {
                  size: 14,
                  weight: 'bold'
                },
                callbacks: {
                  label: function(context) {
                    return context.parsed.y + ' events';
                  }
                }
              }
            },
            scales: {
              x: {
                display: false
              },
              y: {
                display: false
              }
            }
          }
        });
      });
    },
    
    destroyed() {
      if (this.chart) {
        this.chart.destroy();
      }
    }
  },

  WordCloud,
};

export default Hooks;
