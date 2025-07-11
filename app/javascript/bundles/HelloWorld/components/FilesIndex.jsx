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
      <div style={{ textAlign: "center", marginTop: 40 }}>
        Loading files...
      </div>
    );
  if (error)
    return <div style={{ color: "red", textAlign: "center" }}>{error}</div>;

  return (
    <div className="files-container">
      <div className="files-wrapper">
        <div className="file-header">File Manager</div>
        <button className="button-base button-create" onClick={handleCreateNew}>
          + Upload New File
        </button>
        {uploadSuccess && <div className="success-msg">Upload successful!</div>}
        {createSuccess && (
          <div className="success-msg">File created successfully!</div>
        )}
        {files.length === 0 ? (
          <div className="no-files">No files found.</div>
        ) : (
          <div className="file-table">
            <div className="table-header">
              <span style={{ paddingLeft: "30px" }}>Name</span>
              <span style={{ paddingRight: "200px" }}>Actions</span>
            </div>

            {files.map((file) => (
              <div key={file.id} className="table-row">
                <span className="file-name" style={{ marginLeft: "30px" }}>
                  {editingId === file.id ? (
                    <input
                      className="file-input"
                      value={editingName}
                      onChange={(e) => setEditingName(e.target.value)}
                      autoFocus
                    />
                  ) : (
                    file.file_name
                  )}
                </span>

                <div style={{ display: "flex", gap: "20px", flexWrap: "wrap" }}>
                  {editingId === file.id ? (
                    <div className="file-edit-row">
                      <button
                        className="button-base button-update"
                        onClick={() => handleEditSave(file.id)}
                      >
                        Save
                      </button>
                      <button
                        className="button-base button-delete"
                        onClick={handleEditCancel}
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <>
                      <button
                        className="button-base button-history"
                        onClick={() => handleView(file.id)}
                      >
                        View
                      </button>
                      <button
                        className="button-base button-update"
                        onClick={() => handleEdit(file)}
                      >
                        Edit
                      </button>
                      <button
                        className="button-base button-download"
                        onClick={() => handleDownload(file.id)}
                      >
                        Download
                      </button>
                      <button
                        className="button-base button-delete"
                        onClick={() => handleDelete(file.id)}
                      >
                        Delete
                      </button>
                    </>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

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
