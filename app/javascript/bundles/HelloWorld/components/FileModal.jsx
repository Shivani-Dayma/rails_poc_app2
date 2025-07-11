import React, { useState, useRef } from "react";
import "../../styles/FileModal.css";

const FileModal = ({ onClose, onSubmit, templateId = null }) => {
  const fileInputRef = useRef();
  const [fileName, setFileName] = useState("");
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleChooseFile = () => fileInputRef.current?.click();

  const handleFileChange = (e) => {
    setFile(e.target.files[0]);
    setError(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!fileName.trim()) {
      setError("File name is required.");
      return;
    }
    if (!file) {
      setError("Please select a file.");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const formData = new FormData();
      formData.append("file_name", fileName.trim());
      formData.append("file", file);

      const url = "/general_files";
      const response = await fetch(url, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        let msg = "Failed to upload.";
        try {
          const errData = await response.json();
          msg = errData.message || JSON.stringify(errData);
        } catch {}
        throw new Error(msg);
      }

      const data = await response.json();
      onSubmit(data);
      onClose?.();
    } catch (err) {
      setError(err.message || "Something went wrong.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-box">
        <button className="modal-close" onClick={onClose}>
          ×
        </button>
        <form onSubmit={handleSubmit}>
          <label className="form-label">File Name</label>
          <input
            className="form-input"
            type="text"
            value={fileName}
            onChange={(e) => setFileName(e.target.value)}
            placeholder="Enter File name"
            disabled={loading}
          />

          <label className="form-label">Select File</label>
          <input
            type="file"
            ref={fileInputRef}
            className="upload-hidden-input"
            onChange={handleFileChange}
            disabled={loading}
          />
          <button
            type="button"
            onClick={handleChooseFile}
            className="choose-btn"
            disabled={loading}
          >
            {file ? "Change File" : "Choose File"}
          </button>

          {file && <div className="file-name">{file.name}</div>}
          {error && <div className="error-text">{error}</div>}

          <button type="submit" className="submit-btn" disabled={loading}>
            {loading ? "Creating..." : "Create File"}
          </button>
        </form>
      </div>
    </div>
  );
};

export default FileModal;
