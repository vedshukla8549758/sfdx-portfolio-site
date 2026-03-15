/**
 * @description Controller for the Portfolio Site LWC components.
 *              Provides read-only access to Project, Tag, and related records.
 *              All methods are cacheable and enforce FLS via WITH SECURITY_ENFORCED.
 */
public with sharing class projectController {

    private static final Integer DEFAULT_PAGE_SIZE = 12;
    private static final Integer MAX_PAGE_SIZE = 50;

    /**
     * @description Wrapper class for paginated project results.
     */
    public class ProjectResult {
        @AuraEnabled public List<Project__c> projects;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer totalPages;

        public ProjectResult(List<Project__c> projects, Integer totalCount, Integer pageSize, Integer pageNumber) {
            this.projects = projects;
            this.totalCount = totalCount;
            this.pageSize = pageSize;
            this.pageNumber = pageNumber;
            this.totalPages = (totalCount > 0) ? (Integer) Math.ceil((Decimal) totalCount / pageSize) : 0;
        }
    }

    /**
     * @description Wrapper class for filter options returned to the UI.
     */
    public class FilterOptions {
        @AuraEnabled public List<PicklistOption> categories;
        @AuraEnabled public List<TagOption> tags;

        public FilterOptions(List<PicklistOption> categories, List<TagOption> tags) {
            this.categories = categories;
            this.tags = tags;
        }
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class TagOption {
        @AuraEnabled public Id tagId;
        @AuraEnabled public String name;
        @AuraEnabled public String color;

        public TagOption(Id tagId, String name, String color) {
            this.tagId = tagId;
            this.name = name;
            this.color = color;
        }
    }

    /**
     * @description Retrieves a paginated, filterable list of projects.
     * @param searchTerm  Optional keyword to match against Name or Short_Description__c
     * @param category    Optional category picklist value to filter by
     * @param tagIds      Optional list of Tag__c IDs — projects must have ALL specified tags
     * @param pageNumber  Page number (1-based). Defaults to 1.
     * @param pageSize    Records per page. Defaults to 12, max 50.
     * @return ProjectResult containing the page of projects and pagination metadata.
     */
    @AuraEnabled(cacheable=true)
    public static ProjectResult getProjects(
        String searchTerm,
        String category,
        List<Id> tagIds,
        Integer pageNumber,
        Integer pageSize
    ) {
        try {
            // Sanitize pagination inputs
            pageSize = (pageSize == null || pageSize < 1) ? DEFAULT_PAGE_SIZE : Math.min(pageSize, MAX_PAGE_SIZE);
            pageNumber = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;

            // Build dynamic WHERE clauses
            List<String> conditions = new List<String>();
            conditions.add('Status__c != \'Archived\'');

            if (String.isNotBlank(searchTerm)) {
                String safeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
                conditions.add('(Name LIKE \'' + safeTerm + '\' OR Short_Description__c LIKE \'' + safeTerm + '\')');
            }

            if (String.isNotBlank(category)) {
                conditions.add('Category__c = \'' + String.escapeSingleQuotes(category) + '\'');
            }

            // If tag filtering, find project IDs that have ALL specified tags
            if (tagIds != null && !tagIds.isEmpty()) {
                Set<Id> projectIdsWithAllTags = getProjectIdsMatchingAllTags(tagIds);
                if (projectIdsWithAllTags.isEmpty()) {
                    return new ProjectResult(new List<Project__c>(), 0, pageSize, pageNumber);
                }
                // Convert Set to a quoted, comma-separated string for the IN clause
                List<String> quotedIds = new List<String>();
                for (Id pId : projectIdsWithAllTags) {
                    quotedIds.add('\'' + pId + '\'');
                }
                conditions.add('Id IN (' + String.join(quotedIds, ',') + ')');
            }

            String whereClause = String.join(conditions, ' AND ');

            // Count query
            String countQuery = 'SELECT COUNT() FROM Project__c WHERE ' + whereClause;
            Integer totalCount = Database.countQuery(countQuery);

            // Data query with pagination
            Integer offset = (pageNumber - 1) * pageSize;
            String dataQuery = 'SELECT Id, Name, Short_Description__c, Category__c, Status__c, '
                + 'Thumbnail_Image_URL__c, GitHub_Repo_URL__c, Live_Demo_URL__c, '
                + 'Video_URL__c, Tech_Stack__c, Difficulty_Level__c, Featured__c, '
                + 'Sort_Order__c, Date_Published__c, Is_Self_Reference__c, '
                + '(SELECT Id, Tag__r.Name, Tag__r.Color__c FROM Project_Tags__r) '
                + 'FROM Project__c '
                + 'WHERE ' + whereClause + ' '
                + 'ORDER BY Sort_Order__c ASC NULLS LAST, Date_Published__c DESC NULLS LAST '
                + 'LIMIT :pageSize OFFSET :offset';

            List<Project__c> projects = Database.query(dataQuery);

            return new ProjectResult(projects, totalCount, pageSize, pageNumber);

        } catch (Exception e) {
            throw new AuraHandledException('Unable to load projects: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves featured projects for the hero section.
     * @param maxResults Maximum number of featured projects to return. Defaults to 3.
     * @return List of featured Project__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Project__c> getFeaturedProjects(Integer maxResults) {
        try {
            maxResults = (maxResults == null || maxResults < 1) ? 3 : Math.min(maxResults, 10);

            return [
                SELECT Id, Name, Short_Description__c, Category__c,
                       Thumbnail_Image_URL__c, GitHub_Repo_URL__c, Live_Demo_URL__c,
                       Tech_Stack__c, Difficulty_Level__c, Is_Self_Reference__c,
                       (SELECT Id, Tag__r.Name, Tag__r.Color__c FROM Project_Tags__r)
                FROM Project__c
                WHERE Featured__c = true AND Status__c = 'Active'
                WITH SECURITY_ENFORCED
                ORDER BY Sort_Order__c ASC NULLS LAST
                LIMIT :maxResults
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load featured projects: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves a single project's full details with related tags and assets.
     * @param projectId The Id of the Project__c record.
     * @return The Project__c record with child relationships.
     */
    @AuraEnabled(cacheable=true)
    public static Project__c getProjectDetail(Id projectId) {
        try {
            if (projectId == null) {
                throw new AuraHandledException('Project ID is required.');
            }

            List<Project__c> results = [
                SELECT Id, Name, Description__c, Short_Description__c, Category__c,
                       Status__c, Thumbnail_Image_URL__c, GitHub_Repo_URL__c,
                       Live_Demo_URL__c, Video_URL__c, Documentation_URL__c,
                       Tech_Stack__c, Difficulty_Level__c, Featured__c,
                       Sort_Order__c, Date_Published__c, Is_Self_Reference__c,
                       (SELECT Id, Tag__r.Id, Tag__r.Name, Tag__r.Color__c
                        FROM Project_Tags__r
                        ORDER BY Tag__r.Name ASC),
                       (SELECT Id, Name, Asset_Type__c, Asset_URL__c, File_Size__c, Sort_Order__c
                        FROM Project_Assets__r
                        ORDER BY Sort_Order__c ASC NULLS LAST)
                FROM Project__c
                WHERE Id = :projectId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (results.isEmpty()) {
                throw new AuraHandledException('Project not found.');
            }

            return results[0];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load project details: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves available filter options (categories and tags) for the filter UI.
     * @return FilterOptions containing category picklist values and all active tags.
     */
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        try {
            // Get category picklist values
            List<PicklistOption> categories = new List<PicklistOption>();
            Schema.DescribeFieldResult categoryField = Project__c.Category__c.getDescribe();
            for (Schema.PicklistEntry entry : categoryField.getPicklistValues()) {
                if (entry.isActive()) {
                    categories.add(new PicklistOption(entry.getLabel(), entry.getValue()));
                }
            }

            // Get all tags
            List<TagOption> tags = new List<TagOption>();
            for (Tag__c tag : [
                SELECT Id, Name, Color__c
                FROM Tag__c
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ]) {
                tags.add(new TagOption(tag.Id, tag.Name, tag.Color__c));
            }

            return new FilterOptions(categories, tags);
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load filter options: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves quick stats for the hero component.
     * @return Map with keys: totalProjects, totalTechnologies, totalCategories
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getPortfolioStats() {
        try {
            Integer totalProjects = [
                SELECT COUNT()
                FROM Project__c
                WHERE Status__c = 'Active'
                WITH SECURITY_ENFORCED
            ];

            Integer totalTags = [
                SELECT COUNT()
                FROM Tag__c
                WITH SECURITY_ENFORCED
            ];

            Schema.DescribeFieldResult categoryField = Project__c.Category__c.getDescribe();
            Integer totalCategories = 0;
            for (Schema.PicklistEntry entry : categoryField.getPicklistValues()) {
                if (entry.isActive()) {
                    totalCategories++;
                }
            }

            Map<String, Integer> stats = new Map<String, Integer>();
            stats.put('totalProjects', totalProjects);
            stats.put('totalTechnologies', totalTags);
            stats.put('totalCategories', totalCategories);

            return stats;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load portfolio stats: ' + e.getMessage());
        }
    }

    /**
     * @description Helper method to find Project IDs that have ALL of the specified tags.
     * @param tagIds List of Tag__c IDs to match.
     * @return Set of Project__c IDs that have every specified tag.
     */
    private static Set<Id> getProjectIdsMatchingAllTags(List<Id> tagIds) {
        // Find all project-tag junctions for the given tags
        List<Project_Tag__c> junctions = [
            SELECT Project__c, Tag__c
            FROM Project_Tag__c
            WHERE Tag__c IN :tagIds
            WITH SECURITY_ENFORCED
        ];

        // Count how many of the requested tags each project has
        Map<Id, Integer> projectTagCount = new Map<Id, Integer>();
        for (Project_Tag__c pt : junctions) {
            Integer currentCount = projectTagCount.containsKey(pt.Project__c)
                ? projectTagCount.get(pt.Project__c)
                : 0;
            projectTagCount.put(pt.Project__c, currentCount + 1);
        }

        // Only return projects that match ALL tags
        Set<Id> matchingIds = new Set<Id>();
        Integer requiredCount = tagIds.size();
        for (Id projectId : projectTagCount.keySet()) {
            if (projectTagCount.get(projectId) == requiredCount) {
                matchingIds.add(projectId);
            }
        }

        return matchingIds;
    }
}