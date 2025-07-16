from dotenv import load_dotenv
import os
load_dotenv()

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import boto3
import os
from botocore.exceptions import NoCredentialsError
from werkzeug.utils import secure_filename
from io import BytesIO

app = Flask(__name__)
CORS(app)  # Allow frontend access

# AWS S3 Config
AWS_ACCESS_KEY = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
BUCKET_NAME = "your-s3-bucket-name"

s3 = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

@app.route('/')
def home():
    return jsonify({"message": "Document Locker API is running"})


@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "Empty file"}), 400
    
    filename = secure_filename(file.filename)
    try:
        s3.upload_fileobj(file, BUCKET_NAME, filename)
        return jsonify({"message": f"{filename} uploaded to S3"}), 200
    except NoCredentialsError:
        return jsonify({"error": "AWS credentials error"}), 500


@app.route('/files', methods=['GET'])
def list_files():
    try:
        objects = s3.list_objects_v2(Bucket=BUCKET_NAME)
        files = [obj['Key'] for obj in objects.get('Contents', [])]
        return jsonify({"files": files})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    try:
        file_obj = BytesIO()
        s3.download_fileobj(BUCKET_NAME, filename, file_obj)
        file_obj.seek(0)
        return send_file(file_obj, download_name=filename, as_attachment=True)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True)
