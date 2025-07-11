import React, { useEffect, useState } from "react";
import "../../styles/ViewFile.css"; 

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

  if (error) return <div className="error">{error}</div>;
  if (!data) return <div className="loading">Loading...</div>;

  return (
    <div className="page-bg">
      <div className="container">
        <div className="header">File Details</div>
        <div className="subtitle">Extracted information for uploaded file</div>

        <div className="card">
          <div className="file-name">{data.file_name}</div>
          <div className="uploaded-at">
            Uploaded at: {new Date(data.uploaded_at).toLocaleString()}
          </div>
        </div>

        <div className="extracted-data-card">
          <div className="extracted-data-header">Extracted Records</div>

          {data.extracted_records.length > 0 ? (
            <div className="extracted-data-table-wrapper">
              <table className="extracted-data-table">
                <thead>
                  <tr>
                    {Object.keys(data.extracted_records[0]).map((key) => (
                      <th key={key}>{key}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {data.extracted_records.map((record, index) => (
                    <tr key={index}>
                      {Object.values(record).map((value, idx) => (
                        <td key={idx}>{value}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="no-files">No extracted records available.</div>
          )}
        </div>

        <div className="back-btn-container">
          <button className="back-btn" onClick={() => window.history.back()}>
            ← Back
          </button>
        </div>
      </div>
    </div>
  );
};

export default ViewFile;
