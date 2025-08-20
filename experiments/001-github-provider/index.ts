import * as pulumi from "@pulumi/pulumi";
import * as github from "@pulumi/github";

const config = new pulumi.Config();
const repoPrefix = config.get("repoPrefix") || "pulumi-lab";

const testRepo = new github.Repository("test-repo", {
    name: `${repoPrefix}-test`,
    description: "Test repository created with Pulumi",
    visibility: "private",
    hasIssues: true,
    hasProjects: false,
    hasWiki: false,
    autoInit: true,
    gitignoreTemplate: "Node",
    licenseTemplate: "mit",
});

const developBranch = new github.Branch("develop", {
    repository: testRepo.name,
    branch: "develop",
    sourceBranch: "main",
});

const protectionRule = new github.BranchProtection("main-protection", {
    repositoryId: testRepo.nodeId,
    pattern: "main",
    enforceAdmins: false,
    allowsDeletions: false,
    requiredStatusChecks: [{
        strict: true,
        contexts: ["continuous-integration"],
    }],
    requiredPullRequestReviews: [{
        dismissStaleReviews: true,
        requireCodeOwnerReviews: true,
        requiredApprovingReviewCount: 1,
    }],
});

const issueLabel = new github.IssueLabel("bug-label", {
    repository: testRepo.name,
    name: "bug",
    color: "d73a4a",
    description: "Something isn't working",
});

const enhancementLabel = new github.IssueLabel("enhancement-label", {
    repository: testRepo.name,
    name: "enhancement",
    color: "a2eeef",
    description: "New feature or request",
});

export const repositoryUrl = testRepo.htmlUrl;
export const repositoryName = testRepo.name;
export const repositoryId = testRepo.id;