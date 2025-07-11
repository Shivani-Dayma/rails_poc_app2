import React, { useEffect, useState } from "react";
import "../../styles/ViewFile.css";

const capitalize = (key) =>
  key.replace(/_/g, " ").replace(/\b\w/g, (char) => char.toUpperCase());

const ViewFile = () => {
  const pathParts = window.location.pathname.split("/");
  const id = pathParts[pathParts.length - 1];

  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`/general_files/${id}.json`)
      .then((res) => {
        if (!res.ok) throw new Error("Failed to fetch file details");
        return res.json();
      })
      .then((json) => setData(json.general_file || json))
      .catch((err) => setError(err.message));
  }, [id]);

  const handleDownload = async () => {
    try {
      const response = await fetch(`/general_files/${id}/download_file`, {
        method: "GET",
      });

      if (!response.ok) {
        throw new Error("Failed to download file");
      }

      const blob = await response.blob();

      const contentDisposition = response.headers.get("Content-Disposition");
      let filename = "downloaded_file";

      if (contentDisposition) {
        const match = contentDisposition.match(/filename="?([^"]+)"?/);
        if (match && match[1]) {
          filename = match[1];
        }
      }

      const blobUrl = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(blobUrl);
    } catch (error) {
      alert("Error downloading file: " + error.message);
    }
  };

  if (error) return <div className="error">{error}</div>;
  if (!data) return <div className="loading">Loading...</div>;

  return (
    <div className="page-bg">
      <div className="container">
        <div className="header">File Details</div>
        <div className="subtitle">Extracted information for uploaded file</div>

        <div className="card">
          <div className="file-name">File Name : {data.file_name}</div>
          <div className="uploaded-at">
            Uploaded at: {new Date(data.uploaded_at).toLocaleString()}
          </div>
        </div>

        <div className="extracted-data-card">
          {data.extracted_records.length > 0 ? (
            <div className="record-list">
              {data.extracted_records.map((record, index) => (
                <div key={index} className="record-card">
                  {Object.entries(record).map(([key, value]) => (
                    <div key={key} className="record-field">
                      <span className="field-key">{capitalize(key)}:</span>
                      <span className="field-value">{value || "—"}</span>
                    </div>
                  ))}
                </div>
              ))}
            </div>
          ) : (
            <div className="no-files">No extracted records available.</div>
          )}
        </div>

        <div className="back-container">
          <button className="back-btn" onClick={() => window.history.back()}>
            ← Back
          </button>
          <button className="download-btn" onClick={handleDownload}>
            ⬇ Download File
          </button>
        </div>
      </div>
    </div>
  );
};

export default ViewFile;
