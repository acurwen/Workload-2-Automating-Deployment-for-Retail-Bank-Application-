# Workload 2: Automating Deployment of a Retail Bank Application

## PURPOSE: 
For this workload, I'm deploying a retail bank application to the cloud that is fully managed by AWS. Unlike Workload 1, I'm implementing automated continuous integration and continous deployment in my pipeline by utilizing the Command Line Interface of both AWS and AWS Elastic Beanstalk to create an instance environment that will host my application.

## STEPS: 
## 1. **Cloned Kura repository to my GitHub account**

In GitHub, I clicked “Create a new Repository” → Clicked on the “Import a repository” link on top of the page → Entered the URL of the Kura repository, my GH username, and my new access token as the password → Clicked “Begin Import”.
  
## 2. **Created AWS Access Keys**

In my Workload 2 AWS account, I followed the steps to create new access keys. For my use case, I picked the "Command Line Interface" option as further down in the instructions, I need these keys to configure AWS CLI within my EC2 instance/Jenkins server. Saved my keys for later.

![image](https://github.com/user-attachments/assets/db33257d-aa20-4781-b965-cefd3565afe3)

**What are access keys and why would sharing them be dangerous?**

Access keys are long-term credentials used to give you access to AWS tools. Sharing them is dangerous because they are permanent (unless deleted) and because they grant access to use AWS tools without having to use the AWS web interface. If someone else had my access keys, they could potentially create multiple instance environments or access my files, amongst other capabilities which poses a risk and utilizes my resources. Therefore, they need to be kept secret and safe with whoever is authorized to have that access.

## 3. **Created an EC2 instance called “My Jenkins Server”**

    - AMI (Amazon Machine Image): Ubuntu
    - Instance type: t2.micro
    - Key pair used was my default one
    - Used the default VPC (Virtual Private Cloud)
    - Security group rules included HTTP (Port: 80), SSH (Port: 22), and Jenkins (Port: 8080)
    - Storage was set to 1x8 GiB and gp3 (General Purpose SSD) Root Volume

Instance made:

![image](https://github.com/user-attachments/assets/90003980-327f-4c5d-b928-850eb08af461)


*In the Advanced Details section of the Instance Launch setup page, there was an option to enable CloudWatch. I thought to enable it to see the monitoring tool work on my new instance, but additional charges would apply so I bypassed this option. Fast forward into creating the EC2, I see that there are Monitoring graphs available for this EC2 regardless. 


## **Installing Jenkins:**

Within my newly created instance, I installed and started up Jenkins with the below code and copied and saved my initialAdminPassword.

```
   $sudo apt update && sudo apt install fontconfig openjdk-17-jre software-properties-common && sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt install python3.7 python3.7-venv
    $sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
    $echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    $sudo apt-get update
    $sudo apt-get install jenkins
    $sudo systemctl start jenkins
    $sudo systemctl status jenkins
```

Running `sudo systemctl status jenkins` showed me that Jenkins was up and running:

![image](https://github.com/user-attachments/assets/85337a39-3318-4b49-8c74-9b0ec802b5d3)

I noticed that the `systemctl status` command also shows metrics around tasks ran, memory and CPU. I kept these in mind when starting to write my Bash script that checks for system resources.

## 4. Writing my `system_resources_test.sh` script that checks for system resources


## **Initial Thought Process:**

For my script, I focused initially on collecting CPU usage. First, I ran the `top` command to see the format output of the ongoing processes. On top of all the processes are what I would describe as the overall metrics. 

From here, I planned to extract the CPU percentage next to 'id' which represents the percentage of CPU that's "idle" or not being utilized at the time. 
Then I'd have that idle amount subtracted from 100 to represent the total percentage of CPU in use. 

![image](https://github.com/user-attachments/assets/f2842ad5-320e-4517-b738-fdeff36d09c6)

Finally I'd write an if statement that would stop the script if the total percentage of CPU in use exceeded 75%. This was the right idea all along, however, somewhere along the lines I was convinced that we had to include a process in our script to be killed, not the actual script itself.

Below is how I go about brainstorming my script while trying to track down what process ID to include in it. Later on in this readme, I come to my original conclusion that it's the script that needs to be stopped (in **"Revisiting the Script"**).



## **Issues with Syntax and "Integer Conversion"**

I ran into a lot of issues writing my script - mainly successfully extracting the idle CPU percentage and making sure the variable I saved it as could be read as an integer. Below are my troubleshooting steps as I tried to figure them out:

To isolate the idle CPU metric, I first tested with the grep command and ran: `top | grep %Cpu`
This command worked to isolate the line starting with '%Cpu(s)', however, the output kept iterating since `top` shows ongoing processes. 

I searched how to get a static output for top and got the flag '-n' that sets the number of times the `top` output will print by adding a number next to it. So I ran `top -n 1 | grep %Cpu` and successfully got only one snapshot of the '%Cpu(s)' line.

![image](https://github.com/user-attachments/assets/8b719214-dfa9-4d7e-a9cf-1128a4259f1e)

Then I connected that command with the awk command via pipe to isolate the idle CPU metric by itself:  

`top -n 1 | grep %Cpu | awk -F ',' '{print $4}'`

The delineator here is a comma, and based on that, the idle CPU metric is the fourth value in that line. This command worked on the command line. 

![image](https://github.com/user-attachments/assets/d222844d-ca5c-4ca6-800a-092e75ccac95)

Starting in my script, I wrote the full command and assigned it to a variable called `idle_cpu`. At first, I ran into a bit of trouble assigning the variable and echoing it to check it, until I remembered that I had to use a $( ) around the full command to assign it. 

![image](https://github.com/user-attachments/assets/99077e77-d817-4dd8-aef3-565ec966f993)

Then I created another variable called `cpu` that would be set equal to 100 minus `idle_cpu`. Thought this would work, however when running the script, I kept getting a syntax issue or command not found error. 

Took me forever to realize that my `idle_cpu` variable still included 'id' in it, so the system wasn't able to read it as just an integer. So I went back to the script to rewrite the `idle_cpu` variable assignment line. 

First I tried changing the delineator to a space, `top -n 1 | grep %Cpu | awk -F ' ' '{print $7}'`, but that gave me a output of `ni,100.0` —which is not what I wanted. 

So I decided to go back to my original command and add a third pipe with `awk` that removes the 'id' part using the delineator of space: `top -n 1 | grep %Cpu | awk -F ',' '{print $4}' | awk -F ' ' '{print $1}'`

Testing this in the terminal gave me the output I wanted. 

![image](https://github.com/user-attachments/assets/9803a292-e638-49f3-9e7d-c899a6a1c72a)

With that set, I went back to my subtraction section. I had the line `cpu=$((100 - "$idle_cpu"))` as my subtraction command, however, I kept receiving a syntax error when running the script. 

From my BASH calc activity, I learned that Bash only supports integers and the idle CPU metric does have a decimal point, ie. '100.0'. I researched how to deal with whole numbers in bash and found the `bc` command that I can grep the subtraction equation to while setting a variable. 

So I rewrote the line as follows: `cpu=$(echo "100 - $idle_cpu" | bc)`

Unfortunately, this (along many rewrites) still threw errors. 

Ultimately, the issue was that my `idle_cpu` variable wasn't being read as either an integer or floating point number. 

To test this, I changed my `idle_cpu` variable to '99.1' and the above subtraction expression finally worked. 

I thought that how I saved the variable earlier was fine because the output worked on the command line, however, when I tested `top -n 1 | grep %Cpu | awk -F ',' '{print $4}' | awk -F ' ' '{print $1}'` by echoing the variable I saved it to, the command line printed out nothing. 

![image](https://github.com/user-attachments/assets/030ec697-bb0b-47ee-bd3d-44b450fc115e)

I ended up splitting the command into two parts and therefore two variables and finally got the right answer returned. So my original issue was how my `idle_cpu` variable was saved. Later on I changed the delineator in the second command to a '.' so I could record the percentage without the decimal point to the `no_id` variable instead. 

![image](https://github.com/user-attachments/assets/b0fb1fe7-7f1c-42a1-bb38-ce00ba6baad3)

Result:

![image](https://github.com/user-attachments/assets/c651d5b9-b204-4fec-b0c1-de3980a7cf4a)

Although this worked to isolate the idle CPU, the arithmetic still didn't work which indicated that the `no_id` variable was still not read as a valid integer.

In a new script, I changed my first command to `idle_cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")`  which was a combination of what I had before plus the sed command which removed everything starting from the decimal and just kept the integer representing the idle CPU.

Finally this worked and I was able to subtract by 100.

Then I added in an echo message to test all three variables, `idle_cpu`, `no_id`, and `cpu_used`. Each value was echo'd successfully.
![image](https://github.com/user-attachments/assets/de7744cc-16b1-461f-9b50-a5a9ddc8ef9e)


## If Loop
Onto my if loop —I used the `-ge` flag to set a conditional that if `cpu_used` equals or exceeds 75% then to kill a process. (I used 75 because in class we learned that 65-75% is the typical range threshold for max CPU usage.) However, at this point I wasn't sure yet of what process needed to be killed nor its corresponding process ID so I decided to fill that in later. 


In the meantime, below was my script and I updated the GH repository with it.
![image](https://github.com/user-attachments/assets/ec8248e5-ca9c-43c6-a049-c189817891d1)

## **Thinking through what "process" needed to be stopped by my script:**

Off the bat, I thought the process might either be the Jenkins build or creating the virtual environment via Elastic Beanstalk. I thought about who is running this script and when it was running and questioned if it was the Jenkins user while running the build.

Because I am pushing this script to my GitHub repository, it would be included when I connected the code to Jenkins to run a build. And I also noticed that where my script is run in the Jenkins file is in the "Test" stage. So while testing, my script is ran to see if resources are being used. And if too much CPU is being used, I assume the Jenkins build has to stop. 

Future Note: I was on the right track here, but again, I was caught up on finding a process ID to kill in the script instead of realizing that it's the script that's supposed to stop (if resources meet a set threshold).


## 5. **Create a MultiBranch Pipeline and connect your GH repo to it**

In my EC2 "My Jenkins Server", I ran `sudo systemctl status jenkins` to make sure Jenkins was still running and it was. Then I navigated to the web interface to create my pipeline using my EC2 public IP alongside 8080 (the Jenkins port). Next, I entered my admin password that I saved when first installing Jenkins, created a first admin user account and saved my credentials.

Named my pipeline "workload2" —kept it lowercase and one string because according to the instructions, I'd have to search for this directory later on.

The URL of my GH repository was validated.
![image](https://github.com/user-attachments/assets/79863330-9f9f-4e19-9a81-90bf343e5a19)

Building...
![image](https://github.com/user-attachments/assets/d694c4e4-5798-43b4-b72b-3e5736794f3a)


## 6. **Installed AWS CLI on the Jenkins EC2 Server**
   
While I waited for the build to finish, I installed the AWS Command Line Interface back in my EC2 instance with the below code.

```
$curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
$unzip awscliv2.zip
$sudo ./aws/install
$aws --version
```

Initially, I didn't have the command `unzip` so I installed it with: `sudo apt install unzip`. 

Ran into the same issue with the `aws` command so also installed it using `sudo snap install aws-cli`. 

The `apt install` option shown below did not work because the package could not be found. And to run the `sudo snap install aws-cli` command, I had to verify that I wanted to install it by adding  `--classic` at the end of the command.

![image](https://github.com/user-attachments/assets/76da277e-1190-4e7e-829a-13ba4547156e)

Installation worked afterwards and the version number output to the terminal was `aws-cli/2.17.30 Python/3.11.9 Linux/6.8.0-1013-aws exe/x86_64.ubuntu.24`.

![image](https://github.com/user-attachments/assets/364a31ac-43db-44f6-9bc2-ce85d9d8be73)


## 7. **Switched to the "jenkins" user**
   
First, I ran the command `sudo passwd jenkins` to create a password for the "jenkins" user. Saved it to "je".
Then I used the command `sudo su - jenkins` to switch to the "jenkins" user.

## 8. **Navigated to the pipeline directory**

The name of my pipeline directory is "workload2_main".

I used the command `cd workspace/"workload2_main` to navigate to the pipeline directory within the Jenkins "workspace".
There, I was able to see the application source code.

![image](https://github.com/user-attachments/assets/c28e27a0-b0cb-4c36-b6c0-eea7ff05c984)

At this point, I ntoiced that my Jenkins build was still processing and started to wonder if the process I needed to include in my script was the Jenkins build. 
Because my build was still processing, I ran the `top` command to see if the build would show up as an active process.

In the `top` output, I saw a process where the user is jenkins, PID is 518, and at that moment in time: 0.7% of CPU was utilized and 51.0% of memory was used by it. In addition, the command of the process was "java". 

```
  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND                                                                                                                                                                         
    518 jenkins   20   0 2557876 500076  15832 S   0.7  51.0   1:17.73 java 
```

Since the only other process where jenkins is the user was the `top` command I ran, and a significant amount of memory was being used for the java command, I assumed this process represented my ongoing build in Jenkins. 

`top` and 'java' commands together:

![image](https://github.com/user-attachments/assets/c59bc03a-6f0f-42a5-89ee-c0c4d9412c6a)

I also noted that while I left my `top` output running, I did see that the CPU and MEM percentages oscillated between different values. I interpreted that as being proof that if this line did in fact represent my Jenkins build, it wasn't stalled, but rather just taking a super long time. 

I also looked to the time metric to get more clues and was initally confused by the time shown with the "java" command. It was only '1:21.76' at one point meaning that the process had been running for only 1 minute, 21 seconds, and 76 hundredths of a second of CPU time -- and I definitely had the Jenkins build processing for longer than that (or so I thought). 

Then as I kept watching the changing output of `top`, I noticed that the top command itself would reappear showing super small times, for example: only 7 hundredths of a second of CPU time. And that led me to start wondering if the time I saw for the "java" command was not actually representative of the Jenkins build and instead was representing Jenkins as a whole that was installed on this EC2. And if that was right, it would make sense why it would take up so much memory. 

At this time, I decided to keep the `top` command running just to keep an eye on all the metrics (CPU, memory and time) as they oscillated and opened my instance in a new tab to move on to next steps. 

When trying to figure out what was going on with my ongoing Jenkins build, I took a look at the Jenkins file in my GH repository. I looked at the code in the 'Test' stage and realized I completely forgot to save my script as `system_resources_test.sh` because that's the name the Jenkins file points to. I had named my script to `CPUcheck.sh` and started to wonder if that's why the build was still proccessing. Short answer is yes. 

Jenkins file:

![image](https://github.com/user-attachments/assets/55566e40-82c8-4c5b-8d07-e20ce1d3bf82)

On the pipeline history page, I saw that the build failed at the test stage. 

![image](https://github.com/user-attachments/assets/a54395dc-c292-4046-a063-492502949116)

The processing status bar on the page led me to think that the build was ongoing, but as I hovered over the processing status bar, I saw a 'null' status so no, the build had not been running all this time. It in fact, had failed some time before. fantastic.

![image](https://github.com/user-attachments/assets/d31d2541-d95e-4baa-bb29-897124b95b82)

In addition, I saw in my ongoing `top` output that the 518 'java' process was still present even though the build had failed a while ago. So, my theory about it representing the build was out the window and I instead thought that the 518 is most likely the process of hosting Jenkins on the EC2. 

Killing this 518 process meant I would stop Jenkins from running and because that would stop the build configuration, I wondered if this is the process code that needed to be killed —especially if the script is being run during the Jenkins build. 

In the meantime, I went back to my GH repository and renamed the script to system_resources_test.sh.

![image](https://github.com/user-attachments/assets/fd4f4bf8-f13c-4d76-93fb-461fb905b75d)


Then I entered and validated the updated GH URL into a new build and re-ran the pipeline. (Later on, I realize there's no need to re-enter the URL since I commmitted the changes to the original URL and that would defeat the purpose of trying to automate most of this process.)

![image](https://github.com/user-attachments/assets/74a9a6f2-c7a0-4a3b-9322-d4776bf91559)

I also navigated to my pipeline directory in the Java workspace to verify that the script had been updated and it was:

![image](https://github.com/user-attachments/assets/d523dad1-037d-4d55-84ad-4e2b5770f1e1)


The testing stage successfully ran the second time around due to my script name matching what was set in the Jenkins file.
![image](https://github.com/user-attachments/assets/86dab2b4-b509-4775-a00a-5a2d2b27af37)



## 9. **Activated the Python Virtual Environment**

Moving on, I ran `source venv/bin/activate` back in my instance to activate the Python virtual environment.
I got a "No such file or directory" error when running the command both as a jenkins user and as the default ubuntu user.

![image](https://github.com/user-attachments/assets/e4a56173-efef-4c4c-a830-ee5a070fcefe)

I started to think that somehow my virtual environment wasn't created. 

Further down the instructions, I saw that we are to add in a 'Deploy' stage to our Jenkins file and I noticed that the code block included the same source command. This prompted me to look at Workload 1's Jenkins file in comparison to Workload 2's. 

The test stage had been changed to only include my resource check script and didn't include that source command like in Workload 1. I started to wonder if I needed to edit the 'Test' stage part of the file too to include the source command... and also wondered if it was actually the source command that was the process to be killed in my resource check script. (No, it wasn't.)

Before changing my script, I went searching in the directories of both jenkins and ubuntu users to see if I could find the 'venv' directory, in the case the path was possibly wrong. 

![image](https://github.com/user-attachments/assets/c62dd169-4d3c-4349-9f0a-73e59ceb90c7)

I thought to navigate out of the directories and see what was running at the root level. I ran `cd /` and  `ls` and nothing was there.

Finally, I went back into the workspace of my pipeline and found the venv directory. I realize Step 8 in the instructions had already told us to navigate there (facepalm), but I was so focused on figuring out my Jenkins build fiasco that I had been moving around in the instance and reviewing ongoing processea. 

Ran the source command to activate the Python Virtual Environment and it worked. Now my command line user info started with a parentheses, indicating that I was working within the venv.

![image](https://github.com/user-attachments/assets/876e5e1f-5a8d-4781-b220-b2886b4524e4)

**What is a virtual environment? Why is it important/necessary? and when was this one (venv) created?** 

Virtual environments are isolated environments that can be configured to have just enough resources (size, CPU, libraries) for whatever they are needed for. They are important because they host particular projects in isolation so you don't have to worry about conflicts, for example, with various versions of one project or having to install anything on your personal physical server. They are also easy to duplicate if needed.

This virtual environment was created during the Jenkins build, as the `python3 -m venv [name-of-environment]` command is in the 'Build' stage of the Jenkins file.

## 10. **Installed AWS EB CLI on the Jenkins EC2 server**
    
I ran the below commands to install the AWS Elastic Beanstalk Command Line Interface onto my EC2 while within my venv. 

```
$pip install awsebcli
$eb --version
```

I was unsure if I had to be in a certain directory before installing. I decided to stay where I was (in my pipeline directory) and installed AWS EB CLI and it worked, but I also received a head detached message. I took that to mean that my repository in GH wasn't updated since I'd been making changes within this pipeline. I think, however, that as long as I was in the virtual environment it shouldn't make a difference.

![image](https://github.com/user-attachments/assets/52dddd26-8fed-4aba-be35-d77b780f2be4)

The version number output to the terminal was EB CLI 3.20.10 (Python 3.7.17 (default, Apr 27 2024, 21:22:13) [GCC 13.2.0]).

## 11. **Configured AWS CLI**

Ran `$aws configure` to configure the AWS Command Line Interface.

Used my access key and secret access key that I created in step 2.

Other settings:

    - region: "us-east-1"
    - output format" "json"
    
![image](https://github.com/user-attachments/assets/6a76e81d-2bf3-43a2-b301-7466c15d0589)


Ran `$aws ec2 describe-instances` and confirmed that the AWS CLI had been configured.


![image](https://github.com/user-attachments/assets/1ab01277-9304-4d5f-9ca2-62eeb0d7ac4a)


Note: Whenever I ran this command, it froze my instance where even Ctrl + C wouldn't allow me to keep typing. So I refreshed my instance, activated the virtual environment again and moved on to the next step.

## 12. **Initialized AWS Elastic Beanstalk CLI**

Next, I ran `eb init` to initialize the environment to host the bank app.

Other settings for the instance:

    - Default region to: us-east-1 (had to type in '1' for this option)
    - Application name: bankapp
    - python3.7 (had to type in '4' for this option)
    - "no" for code commit
    - "yes" for SSH; Created a new KeyPair


For the keypair, I decided to make a new one because I thought it would be more secure to have a set keypair for this instance itself. After creating it, I got a warning message that the SSH public key I made had been uploaded into EC2 for region us-east-1 - which I believe was a good sign since it'll be accessible in the instance it was made for. 

I also kept getting the deattached head message as I went through the steps, but I realized it wasn't a problem, it's just indicating that changes were being made in the branch.
![image](https://github.com/user-attachments/assets/5fce0bcd-c760-4477-bf53-306baede4a74)

At this point, I saw that per the instructions, we are not committing the changes, so again it should be fine and my GH repository won't be updated with the venv files. 
![image](https://github.com/user-attachments/assets/2f5bf6a3-341a-44dc-a2b4-12601e84ebe8)



## 13. **Added a "deploy" stage to the Jenkinsfile**


Next I added the deploy code block below to my Jenkins file after the "Test" stage to represent the "Deploy" stage.

The instructions imply staying in the workspace to make the edit and then pushing it to GH, but I was worried about running into issues with using git push or git commit.

I ran a git status to review the git push commands and I saw that that .venv was in the ignored files section which made me think that, again, it didn't matter where I made the edits since I'm not pushing any of the changes made to the virtual environment to GH. 

I could edit the Jenkins file in GH and it should work or edit it in the instance and push it to GH and it'd still work. So I made the changes in GH. After commiting the changes in GitHub, I checked in the instance that my Jenkins file was updated as well and it was. 

Lastly, I needed to find the name of my environment and found out it's just 'venv', the text within the parentheses that showed up once I activated the environment and also in the Jenkins file. 

```
stage ('Deploy') {
          steps {
              sh '''#!/bin/bash
              source venv/bin/activate
              eb create venv --single
              '''
          }
      }
```
![image](https://github.com/user-attachments/assets/e73ee60a-03f9-498c-bd30-5daf5110cf10)

I also thought to run top command just to see if there are any changes in processes, and still I saw the same java process with pid 518. Ultimately, I believe this is the process to keep track of and the metric to track is memory used –and at this point, it's using 55.4% of the memory.


![image](https://github.com/user-attachments/assets/c9494536-76d5-41f5-925a-f074033521ce)

## 14. **Build the pipeline again**

Back in the Jenkins web console, I built the pipeline again with the GitHub repository link. 
Build completed successfully.

![image](https://github.com/user-attachments/assets/02c46aa5-6f7c-4290-bcad-ea430845b101)


## 15. **Verify EB environment and application**

Went to Elastic Beanstalk on my browser and verified that an environment was created and the retail bank application was successfully deployed.

Instance environment:

![image](https://github.com/user-attachments/assets/18079fac-a2c6-436e-a03c-0ccbb86174e2)

Bank App:

![image](https://github.com/user-attachments/assets/6779f184-c50a-4742-a400-41d37cb26837)

## Revisiting the script:

While in venv, I ran `top` again and I was seeing the same 518 java process command. 

I really didn't understand if it was the 518 process that I had to kill in my script because that implied I'd kill Jenkins as a whole -- which felt wrong.

I decided to reset and list out what we are supposed to do in the script again like how Kingman wrote it in Slack: 

1. check for system resources
2. have conditional statements for IF a certain resource exceeds a certain set threshold
3. and IF it does.. THEN it should EXIT the script with an error or ELSE the script completes.

So here's what I knew:

The script runs during the TEST stage of the Jenkins file which is ran during a Jenkins build. 

That means me as a first admin user is running it, or we can just say Jenkins is the user who's running it. 

So if my script has to be exited or stopped if a condition is met, that means my TEST stage of the build is what is stopped if resources meet a certain threshold. 

So, because I didn't see any other process within my jenkins server that related to Jenkins or the venv, I am took a hunch that I needed to monitor Jenkins itself on my EC2, and if it uses too much memory, say during a build, that I stop the Test stage and therefore stop the whole build. 

And if that's the case, I didn't need to look for a process ID at all all this time. I just had to include a stop in the script itself.

Even though I am unsure if I got the process right, I do feel confident in my understanding of the role of the script at this point. In this case, exit codes are important because they stop the build process if something is wrong. 

**Why are exit codes important? Especially if running the script through a CICD Pipeline?**

Exit codes help stop running a script when a certain condition is met which is important because they help prevent issues from arising in a system like CI/CD where every process is designed to be continuous and constantly updating. That constant updating or "movement" through the CI/CD pipeline needs to be stopped if any issues arise to protect the application code and the application itself, in this case. 

## Pivoting to Memory:

Because the 518 line I had been tracking all this time included a large memory usage I decided to focus on memory instead when editing my script.

From `top`, at a certain point in time, I saw that the overall memory used was 863.1 MiB, 85.4 MiB was free and 957.4 MiB was the total allotted (and MiB stands for Mebibytes). 

With that in mind, I wrote my script to exit out if memory exceeds 900 Mebibytes and if not, to keep running.     
![image](https://github.com/user-attachments/assets/c0d2e925-ea30-419a-abe2-3fccf814e4ad)

I rewrote my script as follows:

Used `top -b -n1 | grep "MiB Mem"` to isolate the line in the header in `top` for memory.

![image](https://github.com/user-attachments/assets/c717a9c6-88ff-4c4a-8fc1-6e9cecef6b55)

Then used `awk '{print $6}'` where the delineator is a blank space that isolates the used memory on it's own. Similar to before, I combined them into one statement with another pipe.

![image](https://github.com/user-attachments/assets/c1d3ae95-012c-47cb-8219-67d6b5305de7)

Then to avoid my earlier issue, I made sure that the variable I saved as the memory used (`used_mem2`) could be read as an integer by using this command: `used_mem2=${used_mem1%.*}` to remove everything starting from the decimal and after; so for example, 863.1 would turn into 863. 

![image](https://github.com/user-attachments/assets/bcad6702-56f3-4718-acc8-ad9d944b2440)

Saved this script to my repo and ran a Jenkins build. This time, it failed pretty fast because I tested my new script in a different file first and ran nano -l to open it with line numbers. So when I copied it over to my GH repo, I didn't realize I had copied the line numbers as well. So during the build, I got errors for every line. 

Edited the script and ran the build again. Unfortunately, around this point both my EC2 instance, and consequently my Jenkins, started to lag and then fail and I got an error message in GH that my repo had an error while syncing. I think updating my script plus adding in this readme while trying to run the build again partly caused this issue. I could not figure out how to get my EC2 back on unfortunately and wanted to avoid rebooting since this repository was linked to my workspace within it. And then on the Instance page it said that only 1/2 checks had passed.

![image](https://github.com/user-attachments/assets/317e2c79-9447-4cfb-88b2-b3cf0101fff6)

However, before my Jenkins EC2 completely shut down, I was able to test the edited script (without the numbers) while as a jenkins user in the pipeline workspace and it ran as intended. So although I wasn't able to do a successful Jenkins build in time, I know that at least the build would have been able to run the script just fine, in terms of syntax. 

![image](https://github.com/user-attachments/assets/03318580-e973-4e40-85bc-651ba21d8546)

## SYSTEM DESIGN DIAGRAM:

![image](https://github.com/user-attachments/assets/47cbd619-c913-4dee-b343-70152728619c)


Before starting this Workload, I created a draft of this diagram while reading through the instructions. This helped to provide a framework of how to go about doing this project. The most helpful part was adding in the number of each step to understand the order of how we go about deploying the retail application. Then once I finished the project, I went back in to adjust sections and to add details. 


## ISSUES/TROUBLESHOOTING:
(Most of my troubleshooting steps I included in the corresponding sections.)

While creating my security group for my EC2 instance/Jenkins server, I received the below error message when trying to add in the HTTP security rule. The error stated adding HTTP would be a duplicate entry, however, the port was different than the other two (SSH and Jenkins) so I didn't understand the error. I then created a new security group where I *only* added in SSH and got the same error again. To bypass the error, I refreshed the page and clicked "new security group", but before pressing "Edit", there are default options for SSH, HTTPs, HTTP you can check off. I checked off SSH and HTTP, manually added in a security rule for Jenkins and was able to proceed. Perhaps beforehand these default options were checked and I didn't realize, but that wouldn't explain Jenkins because '8080' is not a default port option they had available for quick security group set up —like SSH and HTTP.

![image](https://github.com/user-attachments/assets/6dbe30b6-6ff3-458b-863c-1f6728bef651)


## **Curious about:**

1. Looking into the details of the venv instance, I see that the IAM service roles we made for Workload 1 are already present (AWSElasticBeanstalkWebTier, WorkerTier and MulticontainerDocker). I also see that it has a security group  that has inbound rules of 80 for HTTP and 22 for Jenkins. Wondering where in the setup we implemented either of these things -- I'm guessing the venv's security groups were modeled after the Jenkins instance's security groups.

![image](https://github.com/user-attachments/assets/a1d410bb-6915-4b1f-8147-7deba4927bb8)

2. In my Jenkins server, I noticed while testing that my command lines would be in bold font randomly. Usually they are regular font and I'm not sure what that indicated.


## OPTIMIZATION:
1. **How is using a deploy stage in the CICD pipeline able to increase efficiency of the business?**
    - Using a deploy stage in the CICD pipeline increases efficiency because there is no manual upload of the code. Once the code is confirmed to have successfully gone through the building, testing and staging phases it can be automatically deployed without interference. In addition, we can make alterations to the code and still have it updated and deployed automatically.  
2. **What issues, if any, can you think of that might come with automating source code to a production environment? How would you address/resolve this?**
    - With automation, there’s no need for manual upload which is convenient, but errors in code might not be caught and automatically pushed through to deployment. Utilizing tools such as Jenkins to test the code before it’s staged and deployed can help solve this issue.

## CONCLUSION:
For this Workload, I read through the instructions and answered most of the question prompts to represent my initial thought process. Next, I diagrammed the steps out in draw.io. Then I ran through the project and edited my initial answers and diagram to fill in the missing information I gained from walking through the project. This time around, because we were doing similar steps to Workload 1, I feel like I understand AWS tools and Jenkins a little better. 
