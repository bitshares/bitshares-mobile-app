//
//  VCSearchNetwork.h
//  oplayer
//
//  Created by SYALON on 13-12-24.
//
//  [通用] 从网络动态搜索信息

#import "VCBase.h"

typedef enum ENetworkSearchType
{
    enstAccount = 0,    //  搜索用户（帐号）
    enstAssetAll,       //  搜索资产（所有）
    enstAssetSmart,     //  搜索资产（智能币）
    enstAssetUIA,       //  搜索资产（用户发行）
    enstMax
} ENetworkSearchType;

typedef void (^SelectAccountCallback)(id account_info);

@interface VCSearchNetwork : VCBase<UITableViewDelegate, UITableViewDataSource, UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate>
{
    NSMutableDictionary*        _reg_args;
    
    NSMutableArray*             _array_data;
    NSMutableArray*             _searchDataArray;
    
    NSArray*                    _pSectionTitle;
    NSMutableDictionary*        _pSectionHash;
    
    UISearchController*         _searchController;
}

- (id)initWithSearchType:(ENetworkSearchType)searchType callback:(SelectAccountCallback)callback;

@end
