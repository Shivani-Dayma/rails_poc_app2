import React, { useEffect, useState } from "react";
import "../../styles/FilesIndex.css";
import FileModal from "./FileModal";

const FilesIndex = () => {
  const [files, setFiles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [hovered, setHovered] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [formLoading, setFormLoading] = useState(false);
  const [uploadSuccess, setUploadSuccess] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editingName, setEditingName] = useState("");
  const [createSuccess, setCreateSuccess] = useState(false);

  useEffect(() => {
    fetch("/general_files")
      .then((response) => {
        if (!response.ok) throw new Error("Network response was not ok");
        return response.json();
      })
      .then((data) => {
        setFiles(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  const handleDelete = (id) => {
    if (!confirm("Are you sure you want to delete this file?")) return;
    
    fetch(`/general_files/${id}`, {
      method: "DELETE",
    })
      .then((res) => {
        if (!res.ok) throw new Error("Failed to delete file");
        setFiles((prev) => prev.filter((f) => f.id !== id));
      })
      .catch((err) => alert(err.message));
  };

  const handleView = (id) => {
    window.location.href = `/general_files/${id}`;
  };

  const handleDownload = (id) => {
    fetch(`/general_files/${id}/download_excel`, {
      method: "GET",
    })
      .then((response) => {
        if (!response.ok) throw new Error("Failed to download file");
        return response.blob();
      })
      .then((blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `general_file_${id}_data.xlsx`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
      })
      .catch((err) => alert(err.message));
  };

  const handleCreateNew = () => setShowForm(true);

  const handleFormSubmit = () => {
    fetch("/general_files")
      .then((response) => {
        if (!response.ok) throw new Error("Failed to fetch files after creation");
        return response.json();
      })
      .then((data) => {
        setFiles(data);
        setShowForm(false);
        setCreateSuccess(true);
        setTimeout(() => setCreateSuccess(false), 2000);
      })
      .catch((err) => alert(err.message));
  };

  const handleEdit = (file) => {
    setEditingId(file.id);
    setEditingName(file.file_name);
  };

  const handleEditCancel = () => {
    setEditingId(null);
    setEditingName("");
  };

  const handleEditSave = (id) => {
    fetch(`/general_files/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ file_name: editingName }),
    })
      .then((res) => {
        if (!res.ok) throw new Error("Failed to update file");
        return res.json();
      })
      .then((data) => {
        setFiles((prev) =>
          prev.map((f) => (f.id === id ? { ...f, file_name: data.file_name } : f))
        );
        setEditingId(null);
        setEditingName("");
      })
      .catch((err) => alert(err.message));
  };

  if (loading)
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading files...</p>
      </div>
    );
    
  if (error)
    return (
      <div className="error-container">
        <p>⚠️ {error}</p>
      </div>
    );

  return (
    <div className="files-container">
      <div className="files-wrapper">
        <div className="page-header">
          <div className="header-content">
            <h1 className="page-title">File Manager</h1>
            <p className="page-subtitle">Upload and manage your FSA forms</p>
          </div>
          <button className="upload-button" onClick={handleCreateNew}>
            <span className="upload-icon">+</span>
            Upload New File
          </button>
        </div>

        {/* Success Messages */}
        {uploadSuccess && (
          <div className="alert alert-success">
            <span className="alert-icon">✓</span>
            Upload successful!
          </div>
        )}
        {createSuccess && (
          <div className="alert alert-success">
            <span className="alert-icon">✓</span>
            File created successfully!
          </div>
        )}

        {/* Files Table */}
        <div className="files-card">
          {files.length === 0 ? (
            <div className="empty-state">
              <div className="empty-icon">📄</div>
              <h3>No files uploaded yet</h3>
              <p>Upload your first FSA form to get started</p>
              <button className="upload-button-secondary" onClick={handleCreateNew}>
                Upload Your First File
              </button>
            </div>
          ) : (
            <div className="files-table">
              <div className="table-header">
                <div className="table-cell header-cell">File Name</div>
                <div className="table-cell header-cell">Actions</div>
              </div>

              {files.map((file) => (
                <div key={file.id} className="table-row">
                  <div className="table-cell file-name-cell">
                    {editingId === file.id ? (
                      <input
                        className="file-name-input"
                        value={editingName}
                        onChange={(e) => setEditingName(e.target.value)}
                        onKeyPress={(e) => e.key === 'Enter' && handleEditSave(file.id)}
                        autoFocus
                      />
                    ) : (
                      <span className="file-name">{file.file_name}</span>
                    )}
                  </div>

                  <div className="table-cell actions-cell">
                    {editingId === file.id ? (
                      <div className="action-buttons edit-mode">
                        <button
                          className="action-btn btn-save"
                          onClick={() => handleEditSave(file.id)}
                        >
                          Save
                        </button>
                        <button
                          className="action-btn btn-cancel"
                          onClick={handleEditCancel}
                        >
                          Cancel
                        </button>
                      </div>
                    ) : (
                      <div className="action-buttons">
                        <button
                          className="action-btn btn-view"
                          onClick={() => handleView(file.id)}
                          title="View details"
                        >
                          View
                        </button>
                        <button
                          className="action-btn btn-edit"
                          onClick={() => handleEdit(file)}
                          title="Edit name"
                        >
                          Edit
                        </button>
                        <button
                          className="action-btn btn-download"
                          onClick={() => handleDownload(file.id)}
                          title="Download Excel"
                        >
                          Download
                        </button>
                        <button
                          className="action-btn btn-delete"
                          onClick={() => handleDelete(file.id)}
                          title="Delete file"
                        >
                          Delete
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {showForm && (
          <FileModal
            onSubmit={handleFormSubmit}
            onClose={() => setShowForm(false)}
            loading={formLoading}
          />
        )}
      </div>
    </div>
  );
};

export default FilesIndex;