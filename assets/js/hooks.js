// LiveView hooks for client-side functionality

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
  }
};

export default Hooks;
