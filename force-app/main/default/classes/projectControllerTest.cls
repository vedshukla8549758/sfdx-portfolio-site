/**
 * @description Test class for ProjectController.
 *              Covers all public methods with positive, negative, and edge case scenarios.
 */
@IsTest
private class projectControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Tags
        List<Tag__c> tags = new List<Tag__c>();
        tags.add(new Tag__c(Name = 'LWC', Color__c = '#1B96FF'));
        tags.add(new Tag__c(Name = 'Apex', Color__c = '#FF5733'));
        tags.add(new Tag__c(Name = 'REST API', Color__c = '#00B894'));
        insert tags;

        // Create Projects
        List<Project__c> projects = new List<Project__c>();

        // Self-referencing portfolio project
        projects.add(new Project__c(
            Name = 'Portfolio Hub',
            Short_Description__c = 'The very site you are browsing.',
            Description__c = '<p>A self-referencing portfolio site.</p>',
            Category__c = 'Experience Cloud',
            Status__c = 'Active',
            Tech_Stack__c = 'LWC;Apex;Experience Cloud',
            Difficulty_Level__c = 'Advanced',
            Featured__c = true,
            Is_Self_Reference__c = true,
            Sort_Order__c = 1,
            Date_Published__c = Date.today(),
            GitHub_Repo_URL__c = 'https://github.com/test/portfolio-site',
            Live_Demo_URL__c = 'https://portfolio.example.com'
        ));

        // Standard active project
        projects.add(new Project__c(
            Name = 'Apex REST Service',
            Short_Description__c = 'A custom REST API built with Apex.',
            Description__c = '<p>REST API project details.</p>',
            Category__c = 'Apex',
            Status__c = 'Active',
            Tech_Stack__c = 'Apex;REST API',
            Difficulty_Level__c = 'Intermediate',
            Featured__c = true,
            Sort_Order__c = 2,
            Date_Published__c = Date.today().addDays(-10),
            GitHub_Repo_URL__c = 'https://github.com/test/apex-rest'
        ));

        // Coming Soon project
        projects.add(new Project__c(
            Name = 'Data Cloud Connector',
            Short_Description__c = 'Integration with Data Cloud.',
            Category__c = 'Data Cloud',
            Status__c = 'Coming Soon',
            Difficulty_Level__c = 'Advanced',
            Sort_Order__c = 3
        ));

        // Archived project (should be excluded from default queries)
        projects.add(new Project__c(
            Name = 'Legacy Visualforce App',
            Short_Description__c = 'An old VF project.',
            Category__c = 'Full Stack',
            Status__c = 'Archived',
            Sort_Order__c = 99
        ));

        insert projects;

        // Create Project Tags (junction records)
        Project__c portfolio = [SELECT Id FROM Project__c WHERE Name = 'Portfolio Hub' LIMIT 1];
        Project__c apexRest = [SELECT Id FROM Project__c WHERE Name = 'Apex REST Service' LIMIT 1];
        Tag__c lwcTag = [SELECT Id FROM Tag__c WHERE Name = 'LWC' LIMIT 1];
        Tag__c apexTag = [SELECT Id FROM Tag__c WHERE Name = 'Apex' LIMIT 1];
        Tag__c restTag = [SELECT Id FROM Tag__c WHERE Name = 'REST API' LIMIT 1];

        List<Project_Tag__c> projectTags = new List<Project_Tag__c>();
        projectTags.add(new Project_Tag__c(Project__c = portfolio.Id, Tag__c = lwcTag.Id));
        projectTags.add(new Project_Tag__c(Project__c = portfolio.Id, Tag__c = apexTag.Id));
        projectTags.add(new Project_Tag__c(Project__c = apexRest.Id, Tag__c = apexTag.Id));
        projectTags.add(new Project_Tag__c(Project__c = apexRest.Id, Tag__c = restTag.Id));
        insert projectTags;

        // Create Project Assets
        List<Project_Asset__c> assets = new List<Project_Asset__c>();
        assets.add(new Project_Asset__c(
            Name = 'Architecture Guide',
            Project__c = portfolio.Id,
            Asset_Type__c = 'PDF Guide',
            Asset_URL__c = 'https://github.com/test/portfolio-site/docs/architecture.md',
            Sort_Order__c = 1
        ));
        assets.add(new Project_Asset__c(
            Name = 'Demo Video',
            Project__c = portfolio.Id,
            Asset_Type__c = 'Video',
            Asset_URL__c = 'https://youtube.com/watch?v=test',
            Sort_Order__c = 2
        ));
        insert assets;
    }

    // =========================================================================
    // getProjects — paginated, filtered query
    // =========================================================================

    @IsTest
    static void testGetProjects_NoFilters() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(null, null, null, null, null);
        Test.stopTest();

        // Should return 3 non-archived projects
        System.assertEquals(3, result.totalCount, 'Should exclude archived projects');
        System.assertEquals(3, result.projects.size());
        System.assertEquals(12, result.pageSize, 'Default page size should be 12');
        System.assertEquals(1, result.pageNumber);
    }

    @IsTest
    static void testGetProjects_SearchTerm() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects('REST', null, null, 1, 10);
        Test.stopTest();

        System.assertEquals(1, result.totalCount);
        System.assertEquals('Apex REST Service', result.projects[0].Name);
    }

    @IsTest
    static void testGetProjects_CategoryFilter() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(null, 'Experience Cloud', null, 1, 10);
        Test.stopTest();

        System.assertEquals(1, result.totalCount);
        System.assertEquals('Portfolio Hub', result.projects[0].Name);
    }

    @IsTest
    static void testGetProjects_TagFilter_SingleTag() {
        Tag__c apexTag = [SELECT Id FROM Tag__c WHERE Name = 'Apex' LIMIT 1];

        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(
            null, null, new List<Id>{ apexTag.Id }, 1, 10
        );
        Test.stopTest();

        // Both Portfolio Hub and Apex REST Service have the Apex tag
        System.assertEquals(2, result.totalCount);
    }

    @IsTest
    static void testGetProjects_TagFilter_MultipleTags_AND() {
        Tag__c apexTag = [SELECT Id FROM Tag__c WHERE Name = 'Apex' LIMIT 1];
        Tag__c restTag = [SELECT Id FROM Tag__c WHERE Name = 'REST API' LIMIT 1];

        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(
            null, null, new List<Id>{ apexTag.Id, restTag.Id }, 1, 10
        );
        Test.stopTest();

        // Only Apex REST Service has BOTH tags
        System.assertEquals(1, result.totalCount);
        System.assertEquals('Apex REST Service', result.projects[0].Name);
    }

    @IsTest
    static void testGetProjects_TagFilter_NoMatch() {
        Tag__c lwcTag = [SELECT Id FROM Tag__c WHERE Name = 'LWC' LIMIT 1];
        Tag__c restTag = [SELECT Id FROM Tag__c WHERE Name = 'REST API' LIMIT 1];

        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(
            null, null, new List<Id>{ lwcTag.Id, restTag.Id }, 1, 10
        );
        Test.stopTest();

        // No project has BOTH LWC and REST API
        System.assertEquals(0, result.totalCount);
        System.assertEquals(0, result.projects.size());
    }

    @IsTest
    static void testGetProjects_CombinedFilters() {
        Tag__c apexTag = [SELECT Id FROM Tag__c WHERE Name = 'Apex' LIMIT 1];

        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(
            'Portfolio', 'Experience Cloud', new List<Id>{ apexTag.Id }, 1, 10
        );
        Test.stopTest();

        System.assertEquals(1, result.totalCount);
        System.assertEquals('Portfolio Hub', result.projects[0].Name);
    }

    @IsTest
    static void testGetProjects_Pagination() {
        Test.startTest();
        // Page 1, size 2
        ProjectController.ProjectResult page1 = ProjectController.getProjects(null, null, null, 1, 2);
        // Page 2, size 2
        ProjectController.ProjectResult page2 = ProjectController.getProjects(null, null, null, 2, 2);
        Test.stopTest();

        System.assertEquals(3, page1.totalCount);
        System.assertEquals(2, page1.projects.size());
        System.assertEquals(2, page1.totalPages);
        System.assertEquals(1, page2.projects.size());
    }

    @IsTest
    static void testGetProjects_InvalidPagination() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(null, null, null, -1, 0);
        Test.stopTest();

        // Should default to page 1 and default page size
        System.assertEquals(1, result.pageNumber);
        System.assertEquals(12, result.pageSize);
    }

    @IsTest
    static void testGetProjects_MaxPageSize() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects(null, null, null, 1, 999);
        Test.stopTest();

        System.assertEquals(50, result.pageSize, 'Should cap at max page size of 50');
    }

    @IsTest
    static void testGetProjects_SubqueryReturnsTags() {
        Test.startTest();
        ProjectController.ProjectResult result = ProjectController.getProjects('Portfolio', null, null, 1, 10);
        Test.stopTest();

        Project__c project = result.projects[0];
        System.assertEquals(2, project.Project_Tags__r.size(), 'Portfolio Hub should have 2 tags');
    }

    // =========================================================================
    // getFeaturedProjects
    // =========================================================================

    @IsTest
    static void testGetFeaturedProjects_Default() {
        Test.startTest();
        List<Project__c> featured = ProjectController.getFeaturedProjects(null);
        Test.stopTest();

        System.assertEquals(2, featured.size(), 'Should return 2 featured active projects');
        // Should be ordered by Sort_Order
        System.assertEquals('Portfolio Hub', featured[0].Name);
    }

    @IsTest
    static void testGetFeaturedProjects_LimitedResults() {
        Test.startTest();
        List<Project__c> featured = ProjectController.getFeaturedProjects(1);
        Test.stopTest();

        System.assertEquals(1, featured.size());
    }

    // =========================================================================
    // getProjectDetail
    // =========================================================================

    @IsTest
    static void testGetProjectDetail_Success() {
        Project__c portfolio = [SELECT Id FROM Project__c WHERE Name = 'Portfolio Hub' LIMIT 1];

        Test.startTest();
        Project__c detail = ProjectController.getProjectDetail(portfolio.Id);
        Test.stopTest();

        System.assertEquals('Portfolio Hub', detail.Name);
        System.assertNotEquals(null, detail.Description__c);
        System.assertEquals(true, detail.Is_Self_Reference__c);
        System.assertEquals(2, detail.Project_Tags__r.size(), 'Should include related tags');
        System.assertEquals(2, detail.Project_Assets__r.size(), 'Should include related assets');
    }

    @IsTest
    static void testGetProjectDetail_NullId() {
        Test.startTest();
        try {
            ProjectController.getProjectDetail(null);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Project ID is required'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetProjectDetail_InvalidId() {
        // Use a fabricated ID that won't match any record
        Id fakeId = Project__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        try {
            ProjectController.getProjectDetail(fakeId);
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Project not found'), e.getMessage());
        }
        Test.stopTest();
    }

    // =========================================================================
    // getFilterOptions
    // =========================================================================

    @IsTest
    static void testGetFilterOptions() {
        Test.startTest();
        ProjectController.FilterOptions options = ProjectController.getFilterOptions();
        Test.stopTest();

        // Categories come from the picklist definition, not data
        System.assert(options.categories.size() > 0, 'Should return category picklist values');

        // Verify structure of a category option
        Boolean foundExperienceCloud = false;
        for (ProjectController.PicklistOption opt : options.categories) {
            System.assertNotEquals(null, opt.label);
            System.assertNotEquals(null, opt.value);
            if (opt.value == 'Experience Cloud') {
                foundExperienceCloud = true;
            }
        }
        System.assert(foundExperienceCloud, 'Should include Experience Cloud category');

        // Tags come from data
        System.assertEquals(3, options.tags.size(), 'Should return all 3 tags');
        for (ProjectController.TagOption tag : options.tags) {
            System.assertNotEquals(null, tag.tagId);
            System.assertNotEquals(null, tag.name);
        }
    }

    // =========================================================================
    // getPortfolioStats
    // =========================================================================

    @IsTest
    static void testGetPortfolioStats() {
        Test.startTest();
        Map<String, Integer> stats = ProjectController.getPortfolioStats();
        Test.stopTest();

        // 3 active (non-archived) but only 2 with Status = Active (1 is Coming Soon)
        // Actually: Active = Portfolio Hub + Apex REST Service = 2, Coming Soon = 1
        // The query filters WHERE Status__c = 'Active'
        System.assertEquals(2, stats.get('totalProjects'), 'Should count only Active status projects');
        System.assertEquals(3, stats.get('totalTechnologies'), 'Should count all tags');
        System.assert(stats.get('totalCategories') > 0, 'Should count active category picklist values');
    }

    // =========================================================================
    // Wrapper class coverage
    // =========================================================================

    @IsTest
    static void testProjectResult_TotalPages() {
        // 25 records with page size 10 = 3 pages
        ProjectController.ProjectResult result = new ProjectController.ProjectResult(
            new List<Project__c>(), 25, 10, 1
        );
        System.assertEquals(3, result.totalPages);

        // 0 records = 0 pages
        ProjectController.ProjectResult emptyResult = new ProjectController.ProjectResult(
            new List<Project__c>(), 0, 10, 1
        );
        System.assertEquals(0, emptyResult.totalPages);
    }
}