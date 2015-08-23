module BBQ.SG.Tools.IO (
  prepareFolders   
, renderAllPosts
, renderPage
, syncImages
, syncJs
, syncCss
) where

import BBQ.SG.Misc
import Data.Set (fromList, intersection, difference, toList)
import BBQ.SG.Config
import BBQ.SG.Meta
import BBQ.SG.Tools.Parser
import BBQ.SG.Tools.ModCache
import BBQ.SG.Tools.AutoKeywords
import BBQ.SG.Tools.Synopsis
import Text.Blaze.Html.Renderer.Text
import Data.Text.Lazy (Text, pack, unpack)
import System.Directory
import System.FilePath
import Control.Applicative((<$>))
import Control.Monad
import Text.Blaze.Html5 (Html)
import Prelude hiding (writeFile)
import qualified Data.Map as M
import Data.Text.Lazy.IO (writeFile)

prepareFolders config = do mapM_ (createDirectoryIfMissing True)
                            $ map (\f -> f config)
                                  [ _postsSta
                                  , _pageSta
                                  , _imgSta
                                  , _jsSta
                                  , _cssSta
                                  , _tagsSta
                                  ]



renderAllPosts :: Config -> CacheMap Meta -> ((Text, Meta) -> Synopsis -> [(FilePath, Int)] -> Html) -> IO ([Meta], CacheMap Meta)
renderAllPosts config cache processor = do
    putStrLn "Generating posts..."

    filenames <- map dropExtensions <$> getFilesEndWith (_postsSrc config) ".md"

    (filenames', cache') <- foldM (\(modfiles, cache) file -> do
                                                  let srcPath = _postsSrc config </> file ++ ".md"
                                                  modTime <- getModTime srcPath
                                                  if isNewEntry srcPath modTime cache then do
                                                        putStrLn $ "updating with " ++ show (srcPath, modTime)
                                                        return (modfiles ++ [file], updateEntry srcPath modTime emptyMeta cache)
                                                        else return (modfiles, cache)
                                                )
                                            ([], cache)
                                            filenames

    let paths = map (\f -> _postsSrc config </> f ++ ".md") filenames'

    keywordsMap <- generateKeyWords config filenames'

    debugPrint config $ show filenames'

    cache'' <- foldM (\cache (filename, m) -> do
                        let fp = _postsSrc config </> filename ++ ".md"
                        maybeContent <- readFileMaybe fp
                        case renderPost m (maybeContent, filename) config processor of
                            Left errMsg -> do
                                putStrLn errMsg
                                return cache'
                            Right (meta, html) -> do
                                writeFileRobust (_postsSta config </> filename ++ ".html") (renderHtml html)
                                modTime <- getModTime fp
                                return (updateEntry fp modTime meta cache)
                        )
                     cache'
                     keywordsMap
    
    let metas = map (\p -> let (Just x) = getEntryData p cache'' in x) $ map (\f -> _postsSrc config </> f ++ ".md") filenames

    return (metas, cache'')

-- renderPost :: M.Map FilePath (M.Map String Int) -> (EitherS String, FilePath) -> EitherS (Meta, Html)
renderPost keywords (maybeContent, filename) config processor = do
    content      <- maybeContent
    (Meta_ t d a tg _, str') <- parseMeta content
    let meta = Meta_ t d a tg ("posts" </> dropExtensions filename ++ ".html")
    let (synopsis, body') = extract str'
    return (meta, processor (pack body', meta) synopsis (M.toList keywords))


-- Generate by URL
renderPage url config html = do
    debugPrint config $ "Generating page " ++ url ++ " ..."
    writeFileRobust (_staticDir config </> url ++ ".html") (renderHtml html)

syncImages config cache = do
    putStrLn "Sync images ..."
    syncResource (_imgSrc config) (_imgSta config) (_srcDir config) (_staticDir config) cache

syncJs config cache = do
    putStrLn "Sync JavaScripts ..."
    syncResource (_jsSrc config) (_jsSta config)  (_srcDir config) (_staticDir config) cache

syncCss config cache = do
    putStrLn "Sync CSS ..."
    syncResource (_cssSrc config) (_cssSta config)  (_srcDir config) (_staticDir config) cache


syncResource srcDir staDir srcRoot staRoot cache = do

    src    <- fromList . filterJust . map (dropPrefix srcRoot . fst) <$> getFileDict srcDir
    static <- fromList . filterJust . map (dropPrefix staRoot . fst) <$> getFileDict staDir

    let notInSrc = toList $ difference static src
    let notInSta = toList $ difference src static
    mapM_ (\invalid -> do
                putStrLn $ "remove invalid " ++ show (staRoot </> invalid)
                removeFile (staRoot </> invalid)
          ) notInSrc
    mapM_ (\new     -> do
                putStrLn $ "add new " ++ show (staRoot </> new)
                copyFileRobust (srcRoot </> new) (staRoot </> new)
          ) notInSta

    let common = toList $ intersection src static

    foldM (\cache commonPath -> do
                let srcPath = srcRoot </> commonPath
                let staPath = staRoot </> commonPath
                srcSize <- getFileSize srcPath -- Sanity Check
                staSize <- getFileSize staPath

                modTime <- getModTime srcPath

                if isNewEntry srcPath modTime cache then do
                    putStrLn $ "updating with " ++ show (srcPath, modTime)
                    copyFileRobust srcPath staPath
                    return $ updateEntry srcPath modTime emptyMeta cache
                  else if (srcSize /= staSize) then
                          error "IMPOSSIBLE HAPPENDS!"
                          else return cache
              ) cache common




