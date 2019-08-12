import jenkins.model.Jenkins
import hudson.model.Computer
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.ProjectMatrixAuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule
import jenkins.model.JenkinsLocationConfiguration
import jenkins.security.QueueItemAuthenticatorConfiguration
import org.jenkinsci.plugins.authorizeproject.GlobalQueueItemAuthenticator
import org.jenkinsci.plugins.authorizeproject.strategy.TriggeringUsersAuthorizationStrategy

def instance = Jenkins.getInstance()

if (instance.getSecurityRealm() == hudson.security.SecurityRealm.NO_AUTHENTICATION) {
    println '--> creating admin and slave accounts'
    def securityRealm = new HudsonPrivateSecurityRealm(false)
    def jenkinsHome = System.getenv('JENKINS_HOME')
    securityRealm.createAccount('admin', new File("$jenkinsHome/.admin_pass").text.trim())
    securityRealm.createAccount('slave', new File("$jenkinsHome/.slave_pass").text.trim())
    instance.setSecurityRealm(securityRealm)
}

if (instance.getAuthorizationStrategy() == hudson.security.AuthorizationStrategy.UNSECURED) {
    println '--> configuring permissions for admin and slave accounts'
    def authStrategy = new ProjectMatrixAuthorizationStrategy()
    authStrategy.add(Jenkins.ADMINISTER, 'admin')
    authStrategy.add(Jenkins.READ , 'slave')
    authStrategy.add(Computer.CONFIGURE, 'slave')
    authStrategy.add(Computer.CONNECT, 'slave')
    authStrategy.add(Computer.CREATE, 'slave')
    authStrategy.add(Computer.DELETE, 'slave')
    authStrategy.add(Computer.DISCONNECT, 'slave')
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
JenkinsLocationConfiguration.get().setUrl("https://localhost")