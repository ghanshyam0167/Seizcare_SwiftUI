import subprocess

cmd = ["xcodebuild", "-project", "Seizcare.xcodeproj", "-scheme", "Seizcare", "-sdk", "iphonesimulator", "build"]
with open("build.log", "w") as f:
    process = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
    
print("Exit code:", process.returncode)
