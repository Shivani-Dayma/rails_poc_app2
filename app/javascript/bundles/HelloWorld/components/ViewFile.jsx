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

  const handleDownloadExcel = async () => {
    try {
      const response = await fetch(`/general_files/${id}/download_excel`, {
        method: "GET",
      });

      if (!response.ok) {
        throw new Error("Failed to download Excel file");
      }

      const blob = await response.blob();
      const blobUrl = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = blobUrl;
      link.download = `extracted_records_${id}.xlsx`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(blobUrl);
    } catch (error) {
      alert("Error downloading Excel file: " + error.message);
    }
  };

  if (error) return <div className="error">{error}</div>;
  if (!data) return <div className="loading">Loading...</div>;

  const hasHeaderInfo = data.header_info && 
    Object.entries(data.header_info)
      .filter(([key]) => key !== 'record_type') // Exclude the record_type field
      .some(([, value]) => value && value.toString().trim() !== '');

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

        {/* Header Information Section */}
        {hasHeaderInfo && (
          <div className="header-info-card">
            <h3 className="section-title">Form Information</h3>
            <div className="header-grid">
              {Object.entries(data.header_info)
                .filter(([key]) => key !== 'record_type') // Exclude record_type from display
                .map(([key, value]) => {
                  if (!value || value.toString().trim() === '') return null;
                  
                  const isFullWidth = ['producer_address', 'legal_description'].includes(key);
                  const label = key.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
                  
                  return (
                    <div key={key} className={`header-item ${isFullWidth ? 'full-width' : ''}`}>
                      <span className="header-label">{label}:</span>
                      <span className="header-value">{value}</span>
                    </div>
                  );
                })
              }
            </div>
          </div>
        )}

        {/* Compliance & Legal Information Section */}
        {data.header_info && (data.header_info.omb_control_number || data.header_info.response_time || data.header_info.privacy_act || data.header_info.legal_authority) && (
          <div className="compliance-info-card">
            <h3 className="section-title">Compliance & Legal Information</h3>
            <div className="compliance-text">
              {data.header_info.omb_control_number && (
                <p><strong>OMB Control Number:</strong> {data.header_info.omb_control_number}</p>
              )}
              {data.header_info.response_time && (
                <p><strong>Estimated Response Time:</strong> {data.header_info.response_time}</p>
              )}
              {data.header_info.privacy_act && (
                <p><strong>Privacy Act:</strong> {data.header_info.privacy_act}</p>
              )}
              {data.header_info.legal_authority && (
                <p><strong>Legal Authority:</strong> {data.header_info.legal_authority}</p>
              )}
              <p className="compliance-note">
                <strong>Note:</strong> This form is submitted in accordance with federal regulations. 
                All information provided is used for program eligibility determination and benefit administration.
              </p>
            </div>
          </div>
        )}

        {/* Extracted Records Section */}
        <div className="extracted-data-card">
          <h3 className="section-title">Extracted Records</h3>
          {data.extracted_records && data.extracted_records.length > 0 ? (
            <div className="record-list">
              <div className="record-table-wrapper">
                <table className="record-table">
                  <thead>
                    <tr>
                      {(data.column_order || Object.keys(data.extracted_records[0])).map((key) => (
                        <th key={key}>{capitalize(key)}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {data.extracted_records.map((record, index) => (
                      <tr key={index}>
                        {(data.column_order || Object.keys(record)).map((key, i) => (
                          <td key={i}>{record[key] || "—"}</td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : (
            <div className="no-files">No extracted records available.</div>
          )}
        </div>

        <div className="back-container">
          <button className="back-btn" onClick={() => window.history.back()}>
            Back
          </button>
          <button className="download-btn" onClick={handleDownload}>
            Download File
          </button>
          {data.extracted_records && data.extracted_records.length > 0 && (
            <button className="download-btn excel-btn" onClick={handleDownloadExcel}>
              Download Excel
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default ViewFile;
