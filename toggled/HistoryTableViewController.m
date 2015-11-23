//
//  HistoryTableViewController.m
//  toggled
//

#import "HistoryTableViewController.h"
#import "Entry.h"
#import "JNKeychain.h"
#import "NSDate+ISO8601.h"
#import "NSDate+DateTools.h"
#import "Utils.h"

@implementation HistoryTableViewController

- (void)loadView
{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0,45,320,200) style:UITableViewStylePlain];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    tableView.dataSource = self;
    [tableView reloadData];
    self.tableView = tableView;
    self.previousEntries = [[NSMutableArray alloc] init];
    [self getRelatedData];
}

// turn off header without needing to reload table
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (NSArray*)getLatestEntries:(NSArray*)entries withLimit:(long)limit
{
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"_at" ascending:NO];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedArray = [entries sortedArrayUsingDescriptors:sortDescriptors];
    if (limit > [entries count])
    {
        limit = [entries count];
    }
    return [sortedArray subarrayWithRange:NSMakeRange(0, limit)];
}

- (void)getRelatedData
{
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
    
    NSURL *url = [NSURL URLWithString:@"https://www.toggl.com/api/v8/me?with_related_data=true"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:10.0];
    
    NSString *apiToken = [JNKeychain loadValueForKey:@"apiToken"];
    NSString *authString = [NSString stringWithFormat:@"%@:%@", apiToken, @"api_token"];
    NSData *authData = [authString dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]];
    
    [request setValue:authValue forHTTPHeaderField:@"Authorization"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    void (^parseData)(NSData*, NSURLResponse*, NSError*) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if(error == nil)
        {
            NSString * text = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            NSLog(@"Data = %@",text);
            NSLog(@"response status code: %ld", (long)[(NSHTTPURLResponse *)response statusCode]);
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:nil];
            NSMutableArray *projects = [[NSMutableArray alloc] init];
            for (NSDictionary *projectJson in json[@"data"][@"projects"]) {
                Project *project = [[Project alloc] initWithDictionary:projectJson];
                [projects addObject:project];
            }
            
            for (NSDictionary *entryJson in json[@"data"][@"time_entries"]) {
                Entry *entry = [[Entry alloc] initWithDictionary:entryJson withProjects:projects];
                [self.previousEntries addObject:entry];
            }
            
            self.previousEntries = [[self getLatestEntries:self.previousEntries withLimit:3] mutableCopy];
            
            [self.tableView reloadData];
        }
        else {
            // TODO: login
        }
    };
    
    NSURLSessionDataTask *getMeDataTask = [session dataTaskWithRequest:request
                                                     completionHandler:parseData];
    [getMeDataTask resume];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.previousEntries count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    /*
     Retrieve a cell with the given identifier from the table view.
     The cell is defined in the main storyboard: its identifier is MyIdentifier, and  its selection style is set to None.
     */
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Configure the cell...
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:CellIdentifier];
    }
    
    // see http://stackoverflow.com/questions/494562/setting-custom-uitableviewcells-height for adjust row sizes
    //    cell.frame = CGRectMake(cell.frame.origin.x, cell.frame.origin.y, cell.frame.size.width, 30.0f);
    NSString *time = @"running";
    long duration = [[self.previousEntries objectAtIndex:indexPath.row] _duration];
    if (duration >= 0)
    {
        time = [self formatTime:[[self.previousEntries objectAtIndex:indexPath.row] _duration]];
    }
    NSString *text = [NSString stringWithFormat:@"%-21s %@",
                      [[[self.previousEntries objectAtIndex:indexPath.row] _projectName] cStringUsingEncoding:NSASCIIStringEncoding],
                      time
                      ];
    cell.textLabel.text = text;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo" size:14.0];

    NSString *description = [[self.previousEntries objectAtIndex:indexPath.row] _description];
    if (!description)
    {
        description = @" ";
    }
    
    NSDate *at = [NSDate fromISO8601String:[[self.previousEntries objectAtIndex:indexPath.row] _at]];
    NSString *ago = [at timeAgoSinceNow];
    
    NSString *descriptionText = [NSString stringWithFormat:@"%-21s", [description cStringUsingEncoding:NSASCIIStringEncoding]];
    NSString *agoText = [NSString stringWithFormat:@"%14s", [ago cStringUsingEncoding:NSASCIIStringEncoding]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
                                 descriptionText,
                                 agoText
                                 ];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:12.0];
    return cell;
}

- (NSString *)formatTime:(long)totalSeconds
{
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = (int)(totalSeconds / 3600);
    
    return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
}

@end