import jenkins.model.Jenkins
import hudson.model.Computer
import hudson.model.Job
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.ProjectMatrixAuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule
import java.util.regex.Matcher
import jenkins.model.JenkinsLocationConfiguration
import jenkins.security.QueueItemAuthenticatorConfiguration
import org.jenkinsci.plugins.authorizeproject.GlobalQueueItemAuthenticator
import org.jenkinsci.plugins.authorizeproject.strategy.TriggeringUsersAuthorizationStrategy

def instance = Jenkins.getInstance()

def getPasswordFromSecretsManager(secretId) {
    def result = "aws secretsmanager get-secret-value --secret-id $secretId --query SecretString --output text".execute()
    result.waitFor()
    if (result.exitValue() != 0) {
        println "Error: $result.text"        
        throw new RuntimeException("Could not get secret: $secretId")
    }
    return result.text.trim()
}

def getValueFromInstanceTags(tagName) {
    def instanceId = new URL('http://169.254.169.254/latest/meta-data/instance-id').getText()
    println "--> aws ec2 describe-tags --filters Name=resource-id,Values=$instanceId Name=tag:$tagName,Values=* --query Tags[*].Value --output text"
    def result = "aws ec2 describe-tags --filters Name=resource-id,Values=$instanceId Name=tag:$tagName,Values=* --query Tags[*].Value --output text".execute()
    result.waitFor()
    if (result.exitValue() != 0) {
        println "Error: $result.text"        
        throw new RuntimeException("Could not get value for tag: $tagName")
    }
    return result.text.trim()
}

if (instance.getSecurityRealm() == hudson.security.SecurityRealm.NO_AUTHENTICATION) {
    println '--> creating common accounts'
    def securityRealm = new HudsonPrivateSecurityRealm(false)
    def jenkinsHome = System.getenv('JENKINS_HOME')

    securityRealm.createAccount('admin', getPasswordFromSecretsManager('jenkins-admin-password'))
    securityRealm.createAccount('slave', getPasswordFromSecretsManager('jenkins-slave-password'))
    securityRealm.createAccount('monitoring', new File("$jenkinsHome/.monitoring_pass").text.trim())
    instance.setSecurityRealm(securityRealm)
}

if (instance.getAuthorizationStrategy() == hudson.security.AuthorizationStrategy.UNSECURED) {
    println '--> configuring permissions for common accounts'
    def authStrategy = new ProjectMatrixAuthorizationStrategy()
    authStrategy.add(Jenkins.ADMINISTER, 'admin')
    authStrategy.add(Jenkins.READ, 'slave')
    authStrategy.add(Computer.CONFIGURE, 'slave')
    authStrategy.add(Computer.CONNECT, 'slave')
    authStrategy.add(Computer.CREATE, 'slave')
    authStrategy.add(Computer.DELETE, 'slave')
    authStrategy.add(Computer.DISCONNECT, 'slave')
    authStrategy.add(Jenkins.READ, 'monitoring')
    authStrategy.add(Job.DISCOVER, 'monitoring')
    instance.setAuthorizationStrategy(authStrategy)

    println '--> configuring access control for builds'
    GlobalQueueItemAuthenticator auth = new GlobalQueueItemAuthenticator(new TriggeringUsersAuthorizationStrategy())
    QueueItemAuthenticatorConfiguration.get().authenticators.add(auth)
}

if (!instance.getCrumbIssuer()) {
    println '--> enabling CSRF protection'
    instance.setCrumbIssuer(new DefaultCrumbIssuer(true))
}

println '--> enabling Agent → Master Access Control'
instance.getInjector().getInstance(AdminWhitelistRule.class)
        .setMasterKillSwitch(false)

println '--> configuring url'
def jlc = JenkinsLocationConfiguration.get()
def publicDns = getValueFromInstanceTags('PublicDNS')
jlc.setUrl("https://$publicDns")

println '--> setting agent port for JNLP'
instance.setSlaveAgentPort(8081)

println '--> setting number of executors'
instance.setNumExecutors(getValueFromInstanceTags('NumExecutors') as int)