"""
Example script to test the FastAPI application programmatically
"""
import requests
import json
from pathlib import Path


BASE_URL = "http://localhost:8000"


def test_health_check():
    """Test the health check endpoint"""
    print("Testing health check...")
    response = requests.get(f"{BASE_URL}/health")
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    assert response.status_code == 200
    print("✅ Health check passed\n")


def test_file_upload(file_path: str):
    """Test file upload endpoint"""
    print(f"Testing file upload with: {file_path}")

    if not Path(file_path).exists():
        print(f"❌ File not found: {file_path}")
        return None

    files = {
        'files': open(file_path, 'rb')
    }

    data = {
        'previous_version': 'V2605.00',
        'new_version': 'V2606.00',
        'story_id': 'US1234567'
    }

    response = requests.post(f"{BASE_URL}/api/upload", files=files, data=data)
    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        print("✅ Upload successful\n")
        return result.get('job_id')
    else:
        print(f"❌ Upload failed: {response.text}\n")
        return None


def test_process_job(job_id: str):
    """Test job processing endpoint"""
    print(f"Testing job processing for: {job_id}")

    response = requests.post(f"{BASE_URL}/api/process/{job_id}")
    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        print("✅ Processing successful\n")
        return True
    else:
        print(f"❌ Processing failed: {response.text}\n")
        return False


def test_list_jobs():
    """Test listing all jobs"""
    print("Testing job listing...")

    response = requests.get(f"{BASE_URL}/api/jobs")
    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        result = response.json()
        print(f"Found {result.get('count', 0)} jobs")
        print("✅ Job listing successful\n")
        return result.get('jobs', [])
    else:
        print(f"❌ Job listing failed: {response.text}\n")
        return []


def test_download_job(job_id: str):
    """Test downloading job results"""
    print(f"Testing download for: {job_id}")

    response = requests.get(f"{BASE_URL}/api/download/{job_id}")
    print(f"Status: {response.status_code}")

    if response.status_code == 200:
        output_file = f"test_output_{job_id}.json"
        with open(output_file, 'wb') as f:
            f.write(response.content)
        print(f"✅ Downloaded to: {output_file}\n")
        return True
    else:
        print(f"❌ Download failed: {response.text}\n")
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("Excel to SQL Converter - API Testing")
    print("=" * 60)
    print()

    try:
        # Test 1: Health check
        test_health_check()

        # Test 2: List existing jobs
        jobs = test_list_jobs()

        # Test 3: Upload and process a file (if test file exists)
        test_file = "dataset_builder/data/business_excels/US1532131_V2601.01 - default value and description updates Medicare_ASC.xlsx"

        if Path(test_file).exists():
            job_id = test_file_upload(test_file)

            if job_id:
                # Test 4: Process the job
                if test_process_job(job_id):
                    # Test 5: Download results
                    test_download_job(job_id)
        else:
            print(f"⚠️  Test file not found: {test_file}")
            print("Skipping upload/process/download tests")
            print("You can test manually using the web interface at http://localhost:8000")

        print("=" * 60)
        print("Testing completed!")
        print("=" * 60)

    except requests.exceptions.ConnectionError:
        print("❌ Error: Cannot connect to the API")
        print("Please ensure the application is running:")
        print("  python web_app/main.py")
        print("  OR")
        print("  .\\web_app\\start.ps1")
    except Exception as e:
        print(f"❌ Error: {str(e)}")


if __name__ == "__main__":
    main()
