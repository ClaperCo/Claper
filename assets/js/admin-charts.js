import {
  Chart,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  LineController,
  Filler
} from 'chart.js';
import 'chartjs-adapter-moment';

// Register Chart.js components
Chart.register(
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  LineController,
  Filler
);

export class AdminCharts {
  constructor() {
    this.charts = {};
    this.defaultOptions = {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        intersect: false,
        mode: 'index'
      },
      plugins: {
        legend: {
          display: true,
          position: 'top',
          labels: {
            usePointStyle: true,
            padding: 20,
            font: {
              size: 12,
              family: 'Inter, system-ui, sans-serif'
            },
            color: 'rgba(255, 255, 255, 0.9)'
          }
        },
        tooltip: {
          enabled: true,
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          titleColor: 'rgba(255, 255, 255, 0.9)',
          bodyColor: 'rgba(255, 255, 255, 0.9)',
          borderColor: 'rgba(255, 255, 255, 0.1)',
          borderWidth: 1,
          cornerRadius: 8,
          displayColors: false,
          padding: 12,
          titleFont: {
            size: 14,
            weight: 'bold'
          },
          bodyFont: {
            size: 13
          }
        }
      },
      scales: {
        x: {
          display: true,
          grid: {
            display: false
          },
          ticks: {
            color: 'rgba(255, 255, 255, 0.7)',
            font: {
              size: 11
            }
          }
        },
        y: {
          display: true,
          grid: {
            color: 'rgba(255, 255, 255, 0.1)',
            drawBorder: false
          },
          ticks: {
            color: 'rgba(255, 255, 255, 0.7)',
            font: {
              size: 11
            },
            callback: function(value) {
              return Number.isInteger(value) ? value : '';
            }
          }
        }
      },
      elements: {
        line: {
          tension: 0.4,
          borderWidth: 3,
          fill: true
        },
        point: {
          radius: 0,
          hoverRadius: 6,
          hoverBorderWidth: 2,
          hoverBorderColor: 'rgba(255, 255, 255, 0.9)'
        }
      },
      animation: {
        duration: 800,
        easing: 'easeInOutQuart'
      }
    };
  }

  createUsersChart(canvasId, data) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    const chartData = {
      labels: data.labels,
      datasets: [{
        label: 'Users',
        data: data.values,
        borderColor: 'rgba(102, 126, 234, 1)',
        backgroundColor: 'rgba(102, 126, 234, 0.1)',
        pointBackgroundColor: 'rgba(102, 126, 234, 1)',
        pointBorderColor: 'rgba(255, 255, 255, 0.9)',
        pointHoverBackgroundColor: 'rgba(102, 126, 234, 1)',
        pointHoverBorderColor: 'rgba(255, 255, 255, 0.9)',
      }]
    };

    if (this.charts[canvasId]) {
      this.charts[canvasId].destroy();
    }

    this.charts[canvasId] = new Chart(ctx, {
      type: 'line',
      data: chartData,
      options: this.defaultOptions
    });

    return this.charts[canvasId];
  }

  createEventsChart(canvasId, data) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;

    const chartData = {
      labels: data.labels,
      datasets: [{
        label: 'Events',
        data: data.values,
        borderColor: 'rgba(16, 185, 129, 1)',
        backgroundColor: 'rgba(16, 185, 129, 0.1)',
        pointBackgroundColor: 'rgba(16, 185, 129, 1)',
        pointBorderColor: 'rgba(255, 255, 255, 0.9)',
        pointHoverBackgroundColor: 'rgba(16, 185, 129, 1)',
        pointHoverBorderColor: 'rgba(255, 255, 255, 0.9)',
      }]
    };

    if (this.charts[canvasId]) {
      this.charts[canvasId].destroy();
    }

    this.charts[canvasId] = new Chart(ctx, {
      type: 'line',
      data: chartData,
      options: this.defaultOptions
    });

    return this.charts[canvasId];
  }

  updateChart(canvasId, data) {
    const chart = this.charts[canvasId];
    if (!chart) return;

    chart.data.labels = data.labels;
    chart.data.datasets[0].data = data.values;
    chart.update('active');
  }

  destroyChart(canvasId) {
    if (this.charts[canvasId]) {
      this.charts[canvasId].destroy();
      delete this.charts[canvasId];
    }
  }

  destroyAllCharts() {
    Object.keys(this.charts).forEach(canvasId => {
      this.destroyChart(canvasId);
    });
  }
}

// Create global instance
window.AdminCharts = new AdminCharts();