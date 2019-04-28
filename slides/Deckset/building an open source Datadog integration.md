background-color: #FFFFFF
text: #00000, alignment(right)
header: #00000, line-height(18), text-scale(3.0)
footer-style: #777777, alignment(right), line-height(8), text-scale(0.5), Avenir Next Regular
code: alignment(left), Monako, line-height(1.5)
build-lists: true

# datadog on steroid


**Frédéric Harper**
Technical Evangelist - Datadog

@fharper
fred.dev

![](../images/superdog.jpg)

[.footer: https://unsplash.com/photos/7-ToFEHzMNw]

---

<!--- you have fun -->

![](../images/pineapple-party.jpg)

[.footer: https://unsplash.com/photos/qWlkCwBnwOE]

^
What is the problem?
What can you do?

---

<!--- where is my integration -->

![](../images/crying.jpg)

[.footer: https://unsplash.com/photos/lQ1hJaV0yLM]

^
nooooooo

---

<!--- don't be sad anymore -->

![](../images/happy.jpg)

[.footer: https://unsplash.com/photos/FtZL0r4DZYk]

^
prerequisites
know a little bit of Python

---

<!--- setup your computer -->

#setup

```bash
# python & pip should be installed
git clone https://github.com/DataDog/integrations-extras.git
pip install "datadog-checks-dev[cli]"
ddev config set extras "~/Documents/code/datadog/integrations-extras/"
ddev config set repo extras
```

---

<!--- write the code -->

#hello world

```bash
ddev create awesome
# step 1: implement the main check logic
# step 2: write the tests
ddev test awesome
```

---

<!--- prepare for deployment -->

[.header: #00000, line-height(18), text-scale(3.0), alignment(right)]
[.text: #00000, alignment(left)]

#configs

1. update `README.md`
1. add configurations to `conf.yaml.example`
1. update `manifest.json`
1. update `metadata.csv`
1. create `service_checks.json`
1. add the default images

---
<!--- build & install -->

#install

```bash
ddev release build awesome
# the agent must be running
sudo datadog-agent integration install -w 
    ~/Documents/code/datadog/integrations-extras/
    awesome/dist/datadog_awesome-0.0.1-py2.py3-none-any.whl
```

^
sudo datadog-agent integration install -w ~/Documents/code/datadog/integrations-extras/awesome/dist/datadog_awesome-0.0.1-py2.py3-none-any.whl

---

<!--- run -->

#run

```bash
mkdir ~/.datadog-agent/conf.d/awesome.d
cp ~/Documents/code/datadog/
    integrations-extras/awesome/datadog_checks/
    awesome/data/conf.yaml.example 
    ~/.datadog-agent/conf.d/awesome.d/conf.yaml
sudo datadog-agent stop
sudo datadog-agent start
sudo datadog-agent status | grep awesome
```

^
cp ~/Documents/code/datadog/integrations-extras/awesome/datadog_checks/awesome/data/conf.yaml.example ~/.datadog-agent/conf.d/

---

<!--- celebrate -->

![](../images/balloons.jpg)

[.footer: https://unsplash.com/photos/TMpqNhMunQY]

^
celebrate
go to https://app.datadoghq.com/check/summary

---

<!--- resources -->

# resources

[.text: #00000, alignment(right), text-scale(0.5)]

**slides**
https://github.com/fharper/mytalks

**code**
https://github.com/fharper/datadog-integration

**doc**
https://docs.datadoghq.com/developers/integrations/new\_check\_howto/

**slack**
https://datadoghq.slack.com/

---

<!--- questions & thanks -->

**Frédéric Harper**

fharper@oocz.net

fred.dev

![original](../images/fharper.jpg)

[.footer: ![](../images/unlicense.png) my talks are release under unlicense]