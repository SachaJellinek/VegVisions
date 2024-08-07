--
  title: "VegVisions-Paper Analysis"
author: "Sacha Jellinek"
date: "21/07/2022"
output: html_document
editor_options: 
  chunk_output_type: console
---

```{r setup, include=FALSE, warning=FALSE}
library(sf)
library(tmap)
library(skimr)
library(visdat)
library(lubridate) # for as_date()
library(tidyverse)
library(viridis)
library(ggrepel)
library(ggspatial)
library(xlsx)
library(s2)
library(tiff)
library(raster)
library(dplyr)
library(ordinal)
library(emmeans)
library(lmtest)
library(multcomp)
library(terra)
#library(wesanderson)
```
## VegVisions data for HWS Mid-term
st_layers("~/uomShare/wergProj/VegVisions/SVA_Survey_All_Final_30052022.gdb")
# read in 
vegSurveyv5a <- st_read("~/uomShare/wergProj/VegVisions/SVA_Survey_All_Final_30052022.gdb", layer="Vegetation_Survey_v5a")
st_coordinates(vegSurveyv5a)
names(vegSurveyv5a)
str(vegSurveyv5a)
MW_bound <- st_read("~/uomShare/wergProj/VegVisions/Mapping/MW Catchments/HWS_Catchments2.shp")
MW_subcatch <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW Catchments/HWS_Subcatchments_region.shp")

dat <- vegSurveyv5a %>% dplyr::select(globalid, site_siteid:Editor, -site_compkey_asset)

# datatype for many cols is wrong and needs fixing 
dat <- dat %>% 
  dplyr::mutate(datetime_format = as_date(dat$datetime_format),
                site_siteid = as.integer(site_siteid), 
                vv_A_structure_score = as.integer(vv_A_structure_score), 
                vv_B_richness_score = as.integer(vv_B_richness_score), 
                vv_C_instreamveg_score = as.integer(vv_C_instreamveg_score), 
                vv_D_patch_score = as.integer(vv_D_patch_score), 
                vv_E_regen_score = as.integer(vv_E_regen_score), 
                vv_F_weediness_score = as.integer(vv_F_weediness_score), 
                ww_highlyinvasive_score = as.integer(ww_highlyinvasive_score))

skim(dat)
dat2<- dat %>% drop_na(vv_A_structure_score)
str(dat2)
dat%>% select(vv_vv_score)
#changing weediness scores
dat2 <- dat2 %>% mutate(weediness = ifelse(vv_F_weediness_score == 1, 4, ifelse(vv_F_weediness_score == 0, 5, ifelse(vv_F_weediness_score == 2, 3, ifelse(vv_F_weediness_score == 3, 2, ifelse(vv_F_weediness_score == 5, 0, ifelse(vv_F_weediness_score == 4, 1,0)))))))
  
MW_subcatchProj <- st_transform(MW_subcatch,  crs = st_crs(dat2))
#Spatial joing of the MW subcatchment data
MW_subcatchProj2 <- st_make_valid(MW_subcatchProj)
st_is_valid(MW_subcatchProj2)
dat3 <- st_join(dat2, MW_subcatchProj2, left = FALSE)

scores2 <- dat3 %>%
  dplyr::select(CATCHMENT, vv_vv_score) %>%
  filter(vv_vv_score  == "0"|vv_vv_score == "1")

anal_dat <- dat3[ c(2, 38:47, 56, 60) ]
sapply(anal_dat, mode)
sapply(anal_dat, class)
transform(anal_dat, vv_E_regen_score = as.numeric(vv_E_regen_score), 
          weediness  = as.numeric(weediness),
          vv_D_patch_score= as.numeric(vv_D_patch_score), 
          vv_B_richness_score = as.numeric(vv_B_richness_score), 
          vv_A_structure_score = as.numeric(vv_A_structure_score), 
          vv_C_instreamveg_score= as.numeric(vv_C_instreamveg_score),
          vv_overall_score= as.numeric(vv_overall_score),
          vv_vv_score= as.numeric(vv_vv_score),
          ww_highlyinvasive_score= as.numeric(ww_highlyinvasive_score))
#cramer_v(anal_dat$vv_E_regen_score, Corr_dat$vv_A_structure_score, correct = TRUE)

anal_dat$vv_B_richness_score <- as.factor(anal_dat$vv_B_richness_score)
anal_dat$vv_D_patch_score <- as.factor(anal_dat$vv_D_patch_score)
anal_dat$vv_A_structure_score <- as.factor(anal_dat$vv_A_structure_score)
anal_dat$vv_overall_score <- as.factor(anal_dat$vv_overall_score)
anal_dat$vv_vv_score <- as.factor(anal_dat$vv_vv_score)
anal_dat$vv_E_regen_score <- as.factor(anal_dat$vv_E_regen_score)
anal_dat$vv_C_instreamveg_score <- as.factor(anal_dat$vv_C_instreamveg_score)
anal_dat$CATCHMENT <- as.factor(anal_dat$CATCHMENT)

model <- clm(vv_D_patch_score ~ weediness + CATCHMENT, data = anal_dat, link = "logit")
summary(model)
anova(model,type = "II")
marginal = emmeans(model, pairwise ~ weediness, adjust="tukey")
marginal
#cld(marginal, alpha = 0.05, adjust  = "tukey")
nominal_test(model)

#Counts VV threats data
vvthreats1 <- separate_rows(anal_dat, vv_threats, sep = ",", convert = TRUE)
anal_dat2 <- as.data.frame(anal_dat)
vvthreats2 <- vvthreats1%>%
  dplyr::group_by(site_siteid, CATCHMENT, vv_vv_score) %>%
  dplyr::summarise(count = sum(!is.na(vv_threats)))
staples_vect <- c("stock", "deer", "rabbit")
anal_dat2$count <- sapply(strsplit(anal_dat2$vv_threats, "_"), function(x){
  sum(x == "deer")})
anal_dat2$count2 <- sapply(strsplit(anal_dat2$vv_threats, "_"), function(x){
  sum(x == "stock")})
anal_dat2$count3 <- sapply(strsplit(anal_dat2$vv_threats, "_"), function(x){
  sum(x == "rabbit")})
anal_dat3 <- anal_dat2 %>%
   replace(is.na(.), 0) %>%
   mutate(n = rowSums(.[15:17]))
str(anal_dat3)
anal_dat3$n <- as.numeric(anal_dat3$n )
graze_mod = clm(vv_overall_score ~ n + CATCHMENT + n*CATCHMENT, data = anal_dat3, link = "logit")
summary(graze_mod)
anova(graze_mod,type = "II")
marginal = emmeans(graze_mod, ~ n + CATCHMENT + n*CATCHMENT)
pairs(marginal, adjust="tukey")
cld(marginal, Letters=letters)
nominal_test(graze_mod)

stock2 <- stock %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))

stockmodel = clm(vv_overall_score ~ n + CATCHMENT, data = stock2)
summary(stockmodel)
deer <- vvthreats1 %>% 
  group_by(site_siteid, CATCHMENT, vv_vv_score) %>%
  mutate(n = str_count(vv_threats, 'threat')) 
deer2 <- deer %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))
deermodel = clm(vv_vv_score ~ n + CATCHMENT, data = deer2)
summary(deermodel)

## Native veg extend
Veg_ext_2070 <- rast("~/uomShare/wergProj/VegVisions/Mapping/Veg_ext2017/NVR2017_EXTENT.tif")
crs(Veg_ext_2070)
crs(MW_subcatch)
crs(Veg_ext_2070) <- "+proj=utm +zone=55 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
e <- ext(244837.501911545, 426350.988301529, 5729929.45050935, 5879687.49769201)
Veg_ext_2070_MW <- crop(Veg_ext_2070, e)

Veg_ext_2070_pts <- rasterToPoints(Veg_ext_2070, spatial = TRUE)
Veg_ext_2070_pts <- as.polygon(Veg_ext_2070)

Veg_ext_2070_MW <- Veg_ext_2070 %>% 
  terra::crop(MW_subcatchProj2)
Deer_pelletmod_pts <- rasterToPoints(Deer_pelletmod_reproj, spatial = TRUE)
# Then to a 'conventional' dataframe
Deer_pelletmod_df  <- data.frame(Deer_pelletmod_pts)
str(Deer_pelletmod_df)
rm(Deer_pelletmod_pts, Deer_pelletmod_reproj)
Fig_veg <- ggplot() + 
  geom_raster(data = Veg_ext_2070, aes(fill = layer, x = x, y = y)) +
  scale_fill_gradientn(colors = rainbow(5), limits=c(0.2,3)) +
  geom_sf(data = Highdeer, fill = "NA", color = "blue", size = 2) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  labs(fill = "Modelled Deer Density (Pellets)", x = 'Longitude', y = 'Latitude')
Fig_deermod

  title: "VegVisions-HWSMidterm"
author: "Yung En Chee"
date: "10/03/2022"
output: html_document
editor_options: 
  chunk_output_type: console
---

```{r setup, include=FALSE, warning=FALSE}
library(sf)
library(tmap)
library(skimr)
library(visdat)
library(lubridate) # for as_date()
library(tidyverse)
library(viridis)
library(ggrepel)
library(ggspatial)
library(ggpubr)
library(xlsx)
library(s2)
library(tiff)
library(raster)
library(dplyr)
library(ordinal)
library(emmeans)
#library(wesanderson)

```

## VegVisions data for HWS Mid-term
This script:    
  i) reads in, explores and tidies VegVisions data provided by Alluvium (EcoFutures).  
ii) ....

```{Loading data and shp files, r warning=FALSE}
# have a look at the layers in the supplied GDB
st_layers("~/uomShare/wergProj/VegVisions/SVA_Survey_All_Final_30052022.gdb")
# read in 
vegSurvey230222 <- terra::vect("~/uomShare/wergProj/VegVisions/SVA_Survey_Locations_Final_22022023_v5a_Checked.shp")
VV_df <- data.frame(values(vegSurvey230222), geom(vegSurvey230222))
vv_map_vect <- vect(VV_df, geom=c("xcoord", "ycoord"), crs="28355")
crs(vv_map_vect)  <- "epsg:28355"
r <- rast(vv_map_vect)
vv_map <- rasterize(vv_map_vect, r)

names(vegSurvey230222)
str(vegSurvey230222)
MW_bound <- st_read("~/uomShare/wergProj/VegVisions/Mapping/MW Catchments/HWS_Catchments2.shp")
MW_subcatch <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW Catchments/HWS_Subcatchments_region.shp")
MW_priority <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW Priority areas/PO_SubCs_Combined_region.shp")
MW_4_5 <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW Priority areas/4s_5s_SubCs_Combined_region.shp")
#Current_veg <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/Veg_Current_EVC_MW/EVC_Veg_Current_MW.shp")
#Urb_grow <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/UrbanGrowthBound/Urban_Growth_boundary.shp")
vv_expertelic <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW_Expert_elicitation_VV/VV_Expert_elicitation_2018_mod_vhigh_conf.shp")
vv_expertelichigh <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/MW_Expert_elicitation_VV/VV_Expert_elicitation_2018_high_vhighconf.shp")
waterways <- st_read ("~/uomShare/wergProj/VegVisions/Mapping/Major_rivers/Major_Rivers_MW.shp")
woody_weeds <- st_read("~/uomShare/wergProj/VegVisions/Mapping/Woody weeds/woody_weeds.shp")
veg_ext <- st_read("~/uomShare/wergProj/VegVisions/Veg_ext_500mBuff_VV.csv")
veg_ext <- veg_ext %>% 
  dplyr::mutate(veg_ext = as.integer(veg_ext),
                site_siteid = as.integer(site_siteid))
#Aridity_change2050 <- st_read("~/uomShare/wergProj/VegVisions/Mapping/Aridity change/Aridity_change_2050.shp")
# Brief explanation/key of layers, please?
#Available layers:
#                              layer_name geometry_type features fields
#1                  Vegetation_Survey_v5a         Point      506     78
#2          Vegetation_Survey_v5a__ATTACH            NA      174      7
#3                          repeat_hazard            NA      538     13
#4        repeat_det_coordinates_transect            NA      240     13
#5       repeat_det_coordinates_start_end            NA        7     11
#6                      repeat_det_canopy            NA      234      8
#7            repeat_det_canopy_intercept            NA     4680     12
#8                        repeat_det_logs            NA      397     10
#9                    repeat_det_quad_tba            NA      453     17
#10          repeat_det_quad_tree_heights            NA      186     13
#11                 repeat_vv_coordinates            NA     1012     13
#12                         Site_Location         Point      506      4
#13                    Master_SpeciesList            NA     4082      2
#14 SiteID_Vegetation_Detailed_Assessment            NA    74499      9
#15   SiteID_Lifeform_Detailed_Assessment            NA     1200     30
#16  SiteID_Transects_Detailed_Assessment            NA      240      7
#17      SiteID_Other_Detailed_Assessment            NA     1120      8

# Fields to check w Alluvium
# 1. site_compkey_asset, start_survey, vv_weed_notes - all entries NA?
# 1. transect_bearing, creek bearing - is this in degrees?
# 2. EVC_vv is an integer value but EVC_vv_other is a character-based description?
# 3. vv_overall_score - thought the max VV score was 25 but this field contains 26, 27, 28, 29, 30
# 4. vv_F_weediness score and vv_weediness_score - why 2 versions? what's the difference?

# lots of columns that are not of interest, so drop & tidy. Dropping fields where all entries NA
#dat <- vegSurveyv5a %>% dplyr::select(globalid, site_siteid:Editor, -site_compkey_asset)

# datatype for many cols is wrong and needs fixing 
dat <- vv_map %>% 
  dplyr::mutate(datetime_format = as_date(vv_map$datetime_f),
                site_siteid = as.integer(site_sitei), 
                vv_A_structure_score = as.integer(vv_A_struc), 
                vv_B_richness_score = as.integer(vv_B_richn), 
                vv_C_instreamveg_score = as.integer(vv_C_instr), 
                vv_D_patch_score = as.integer(vv_D_patch), 
                vv_E_regen_score = as.integer(vv_E_regen), 
                vv_F_weediness_score = as.integer(vv_F_weedi), 
                vv_highlyinvasive_score = as.integer(vv_highlyi))

skim(vv_map)
dat2<- dat %>% drop_na(vv_A_structure_score)
str(vv_map)
dat%>% dplyr::select(vv_vv_score)
#dat2 <- dat2 %>% mutate(weediness = ifelse(vv_F_weediness_score == 1, 4, ifelse(vv_F_weediness_score == 0, 5, ifelse(vv_F_weediness_score == 2, 3, ifelse(vv_F_weediness_score == 3, 2, ifelse(vv_F_weediness_score == 5, 0, ifelse(vv_F_weediness_score == 4, 1,0)))))))

plot(dat2, axes = TRUE)
#plot(dat["site_sitename"])
MW_subcatchProj <- st_transform(MW_subcatch,  crs = st_crs(dat2))
#Spatial joing of the MW subcatchment data
MW_subcatchProj2 <- st_make_valid(MW_subcatchProj)
Aridity_change2050 <- st_transform(Aridity_change2050,  crs = st_crs(dat2))
st_is_valid(MW_subcatchProj2)
dat3 <- st_join(dat2, MW_subcatchProj2, left = FALSE)
dat4 <- left_join(dat3, veg_ext, by = 'site_sitei')
str(df)
ggscatter(dat3, x = "vv_vv_score", y = "site_siteid", 
          add = "reg.line", conf.int = TRUE, 
          cor.coef = TRUE, cor.method = "pearson",
          xlab = "VV_score", ylab = "Site_ID")
#dat2 <- st_make_valid(MW_subcatchProj)
#st_is_valid(MW_subcatchProj)
```

```{Overall R scores, r warning=FALSE}
#knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE, error = FALSE,dev = "png", dpi = 500)
#knitr::opts_chunk$set(fig.width=6.5, fig.height=3) 
#{Fig0, fig.height = 6.5, fig.width = 3}
#Spatial plots of the vegetation visions data and all the related individual scores
Fig0 <- ggplot(data = dat2) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  #geom_sf(data = Current_veg, fill = "lightgreen", colour = NA) +
  #geom_sf(data = Urb_grow, fill = "darkgrey", colour = NA) +
  geom_sf(data = waterways, fill = "NA", colour = "blue", size = 0.4) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  #geom_sf(data = vv_expertelic, fill = "NA", color = "red") +
  geom_sf(aes(color = vv_vv_score), size = 2.5) +
  scale_color_viridis(option = "A", direction = -1,limits = c(0,5), 
                      labels=c("0 = Absent", "1 = Very Low", "2 = Low","3 = Medium","4 = High", "5 = Very High")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Vegetation Visions Score"))
Fig0
#Fig0 = 6.5, fig.height = 3
ggsave('~/uomShare/wergProj/VegVisions/Outputs/vv_score.jpeg', 
       Fig0, device = "png", width = 13, height = 6, dpi = 300)

Corr_dat <- dat4[ c(2, 38:47, 56, 60, 64) ]
sapply(Corr_dat, mode)
sapply(Corr_dat, class)
Corr_dat2 <-transform(Corr_dat, vv_E_regen_score = as.numeric(vv_E_regen_score), 
          weediness  = as.numeric(weediness),
          vv_D_patch_score= as.numeric(vv_D_patch_score), 
          vv_B_richness_score = as.numeric(vv_B_richness_score), 
          vv_A_structure_score = as.numeric(vv_A_structure_score), 
          vv_C_instreamveg_score= as.numeric(vv_C_instreamveg_score),
          vv_overall_score= as.numeric(vv_overall_score),
          vv_vv_score= as.numeric(vv_vv_score),
          ww_highlyinvasive_score= as.numeric(ww_highlyinvasive_score),
          veg_ext= as.numeric(veg_ext))
str(Corr_dat2)
Corr_dat2 <- Corr_dat2[ c(2:10, 12, 14) ]
cor.test(Corr_dat2$vv_D_patch_score, Corr_dat2$veg_ext, 
                    method = "pearson")

Corr_dat$vv_B_richness_score <- as.factor(Corr_dat$vv_B_richness_score)
Corr_dat$vv_D_patch_score <- as.factor(Corr_dat$vv_D_patch_score)
Corr_dat$vv_A_structure_score <- as.factor(Corr_dat$vv_A_structure_score)
Corr_dat$vv_overall_score <- as.factor(Corr_dat$vv_overall_score)
Corr_dat$vv_vv_score <- as.factor(Corr_dat$vv_vv_score)
Corr_dat$vv_E_regen_score <- as.factor(Corr_dat$vv_E_regen_score)
Corr_dat$vv_C_instreamveg_score <- as.factor(Corr_dat$vv_C_instreamveg_score)
Corr_dat$CATCHMENT <- as.factor(Corr_dat$CATCHMENT)
str(Corr_dat)

Corr_dat$logveg_ext=log(Corr_dat$veg_ext+1)

model <- clm(vv_E_regen_score ~ logveg_ext, data = Corr_dat, link = "logit")
summary(model)
anova(model,type = "II")
marginal = emmeans(model, pairwise ~ weediness, adjust="tukey")
marginal
#cld(marginal, alpha = 0.05, adjust  = "tukey")
nominal_test(model)
```

```{Scores 4's & 5's, r warning=FALSE}
scores <- dat2 %>%
  filter(vv_vv_scor  == "4"|vv_vv_scor == "5")
#MW_bound.sf <- st_as_sf(x = MW_bound, 
#                      coords = c("long", "lat"),
#                      crs = "EPSG:28355")
Fig45 <- ggplot(data = scores) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  #geom_sf(data = Aridity_change2050, aes(fill = F__Changes)) +
  #geom_sf(data = Current_veg, fill = "lightgreen", colour = NA) +
  #geom_sf(data = Urb_grow, fill = "darkgrey", colour = NA) +
  geom_sf(data = waterways, fill = "NA", colour = "blue", size = 0.4) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  #geom_sf(data = vv_expertelic, fill = "NA", color = "red") +
  geom_sf(aes(color = vv_vv_scor), size = 2.5) +
  scale_colour_gradient(low = "purple", high = "black", breaks = c(4,5), 
                        labels=c("4 = High", "5 = Very High")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Vegetation Visions Score"))
Fig45
ggsave('~/uomShare/wergProj/VegVisions/Outputs/vv_scores_4_5.jpeg', 
       Fig45, device = "png", width = 13, height = 6, dpi = 300)

Detailed_sites <- 
 dplyr::filter(dat3, survey_method == "Veg_Visions,Detailed")
  
Aridity2050 <- ggplot (data = Aridity_change2050) +
  geom_sf(aes(fill = F__Changes), size = 0.5) + 
    scale_fill_gradient(low = "white", high = "red") +
  geom_sf(data = scores, color = "purple", size = 2) + 
  geom_sf(data = Detailed_sites, color = "black", size = 2)+
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1)+
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Vegetation Visions Score"))
Aridity2050
ggsave('~/uomShare/wergProj/VegVisions/Outputs/Aridity2050.jpeg', 
       Aridity2050, device = "png", width = 13, height = 6, dpi = 300)

scores2 <- dat3 %>%
  filter(vv_vv_scor  == "4"|vv_vv_scor == "5")
MW_high <- st_transform(MW_4_5, crs = st_crs(dat2))
MW_priority <- st_transform(MW_priority, crs = st_crs(dat2))
MW_priority <- st_make_valid(MW_priority)
st_is_valid(MW_priority)
scores_buff_20m <- st_buffer(scores2, 20)
VV_4_5_45high <- st_join(scores_buff_20m, MW_high, left = FALSE)

VV_4_5_prior <- st_join(scores_buff_20m, MW_priority, left = FALSE)

vv_sites_ee_regen <- VV_4_5_prior %>% 
  dplyr::select(site_siteid, CATCHMENT, SUBCATCHME, vv_E_regen_score)%>%
  filter(vv_E_regen_score  == "1"|vv_E_regen_score == "2"|vv_E_regen_score == "0")

VV_4_5_45high2 <- VV_4_5_45high %>% 
  dplyr::select(CATCHMENT, SUBCATCHME) %>%
  count(CATCHMENT, sort = TRUE)
VV_4_5_prior2 <- VV_4_5_prior %>% 
  dplyr::select(CATCHMENT, SUBCATCHME)%>%
  count(CATCHMENT, sort = TRUE)
All_subcatch <- scores2 %>% dplyr::select(CATCHMENT, SUBCATCHME) %>%
  count(CATCHMENT, sort = TRUE)
write.xlsx2(as.data.frame(VV_4_5_45high2), file = "~/uomShare/wergProj/VegVisions/Outputs/VV_4_5_45high2.xlsx", col.names = TRUE)
write.xlsx2(as.data.frame(VV_4_5_prior2), file = "~/uomShare/wergProj/VegVisions/Outputs/VV_4_5_prior2.xlsx", col.names = TRUE)
write.xlsx2(as.data.frame(All_subcatch), file = "~/uomShare/wergProj/VegVisions/Outputs/All_subcatch.xlsx", col.names = TRUE)

VV_45_EE_45 <- VV_4_5_45high %>% 
  dplyr::select(site_siteid, CATCHMENT, SUBCATCHME)
VV_45_EE_prior <- VV_4_5_prior %>% 
  dplyr::select(site_siteid, CATCHMENT, SUBCATCHME)

vv_sites_ee <- dat3 %>% 
  dplyr::select(site_siteid, CATCHMENT, SUBCATCHME, vv_vv_score)%>%
  filter(vv_vv_score  == "4"|vv_vv_score == "5")
dplyr::all_equal(VV_45_EE_45, vv_sites_ee)
write.xlsx2(as.data.frame(VV_45_EE_45), file = "~/uomShare/wergProj/VegVisions/Outputs/VVEEdata_compare.xlsx", col.names = TRUE, sheetName = "VV_45_EE_45")
write.xlsx2(as.data.frame(VV_45_EE_prior), file = "~/uomShare/wergProj/VegVisions/Outputs/VVEEdata_compare.xlsx", col.names = TRUE, sheetName = "VV_45_EE_prior")
write.xlsx2(as.data.frame(VV_45_EE_45), file = "~/uomShare/wergProj/VegVisions/Outputs/VVEEdata_compare.xlsx", col.names = TRUE, sheetName = "VV_45_EE_45")

#df <- left_join(Mon_data, sites_aridity, by = 'site')
df <- left_join(All_subcatch, VV_4_5_prior2, by=c("site_siteid"))
str(df)
erased_tracts1 <- st_difference(All_subcatch, VV_4_5_prior2)
  
lowregen <- dat3 %>%
  filter(vv_E_regen_score  == "0" | vv_E_regen_score  == "1"|vv_E_regen_score  == "2")
Figlowregen <- ggplot(data = lowregen) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  #geom_sf(data = Current_veg, fill = "lightgreen", colour = NA) +
  geom_sf(data = waterways, fill = "NA", colour = "blue", size = 0.4) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(aes(color = vv_E_regen_score), size = 2.5) +
  scale_colour_gradient(low = "yellow", high = "red", 
                        breaks = c(0,1,2), 
                        labels=c("0 = None", "1 = Low","2 = Very low")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "VV21 Regeneration Score"))
Figlowregen
ggsave('~/uomShare/wergProj/VegVisions/Outputs/lowregen.jpeg', 
       Figlowregen, device = "png", width = 13, height = 6, dpi = 300)

Regen_MWHigh <- st_join(lowregen, MW_high, left = FALSE)
Regentable <- Regen_MWHigh %>% dplyr::select(site_siteid, CATCHMENT, SUBCATCHME, vv_E_regen_score, vv_vv_score)
write.xlsx2(as.data.frame(Regentable), file = "~/uomShare/wergProj/VegVisions/Outputs/lowregensites.xlsx", col.names = TRUE)
RegenVV_scores <- dat3 %>%
  dplyr::select(site_siteid, CATCHMENT, vv_E_regen_score, vv_vv_score)%>%
  filter(vv_E_regen_score <3, vv_vv_score>3)
write.xlsx2(as.data.frame(RegenVV_scores), file = "~/uomShare/wergProj/VegVisions/Outputs/lowregensites_VVScores.xlsx", col.names = TRUE)
Connectivity <- dat3 %>%
  dplyr::select(site_siteid, CATCHMENT, vv_D_patch_score, vv_vv_score)%>%
  filter(vv_D_patch_score <3, vv_vv_score>3)
write.xlsx2(as.data.frame(Connectivity), file = "~/uomShare/wergProj/VegVisions/Outputs/Connectivity.xlsx", col.names = TRUE)

Weeds <- dat3 %>%
  dplyr::select(site_siteid, CATCHMENT, vv_F_weediness_score, vv_vv_score)%>%
  filter(vv_F_weediness_score >3, vv_vv_score>3)
write.xlsx2(as.data.frame(Weeds), file = "~/uomShare/wergProj/VegVisions/Outputs/FWeediness_highVV.xlsx", col.names = TRUE)

invWeeds <- dat3 %>%
  dplyr::select(site_siteid, CATCHMENT, ww_highlyinvasive_score, vv_vv_score)%>%
  filter(ww_highlyinvasive_score >3, vv_vv_score>3)
write.xlsx2(as.data.frame(invWeeds), file = "~/uomShare/wergProj/VegVisions/Outputs/HighInvasive_highVV.xlsx", col.names = TRUE)
Allareas <- dat3 %>%
  dplyr::select(CATCHMENT, vv_vv_score)%>%
  count(CATCHMENT, vv_vv_score)
write.xlsx2(as.data.frame(Allareas), file = "~/uomShare/wergProj/VegVisions/Outputs/Allareas.xlsx", col.names = TRUE)
```

```{Diff EE & VV data}
#transform the projections from MW_bound & Subcatchments shape files to match dat
st_crs(dat2)
st_crs(MW_bound)
st_crs(MW_subcatch)
st_crs(vv_expertelic)
MW_expProj <- st_transform(vv_expertelic,  crs = st_crs(dat2))
MW_expProjhigh <- st_transform(vv_expertelichigh,  crs = st_crs(dat2))
MW_boundProj <- st_transform(MW_bound,  crs = st_crs(dat2))
MW_subcatchProj <- st_transform(MW_subcatch,  crs = st_crs(dat2))
#Spatial joing of the MW boundary and then subcatchment data
join_Score_catch <- st_join(dat3, MW_boundProj, left = FALSE)

#join_Score_catch2 <- st_join(join_Score_catch, MW_subcatchProj2, left = FALSE)
#skim(join_Score_catch2)
#remove unnecessary columns
#join_catch <- join_Score_catch2[ -c(3:34, 36, 48) ]
#join_catch <- join_catch[ -c(17:21) ]

#join_Score_catch2 <- st_join(join_Score_catch, MW_subcatchProj2, left = FALSE)

#skim(join_Score_catch2)
#remove unnecessary columns
#join_catch <- join_Score_catch2[ -c(3:34, 36, 48) ]
#join_catch <- join_catch[ -c(17:21) ]


# create join with high expert elicitation data and veg visions data
points_buff_20m <- st_buffer(join_Score_catch, 20)
# EE data 3 to 5 - medium to very high
#join_Score_catch3 <- st_join(points_buff_20m, MW_expProj, left = FALSE)
#ee_vv_data <- join_Score_catch3 %>% distinct(site_siteid, vv_vv_score, .keep_all = TRUE)
# High expert elicitation scores (4 & 5)
high_ee <- st_join(points_buff_20m, MW_expProjhigh, left = FALSE)
ee_vv_data_high <- high_ee %>% distinct(site_siteid, vv_vv_score, .keep_all = TRUE)

ee_vv_diffhigh <- ee_vv_data_high %>% 
  group_by(site_siteid, CATCHMENT.x, SUBCATCHME, LABEL, vv_vv_score, X_030_VV) %>%
  summarise(diff=vv_vv_score-X_030_VV)
str(ee_vv_diffhigh)

#data table showing only sites with high levels of difference
data_table <- ee_vv_diffhigh %>%
  filter(diff == "3" | diff == "2"| diff == "-2")
print(data_table)
write.xlsx(as.data.frame(data_table), file = "~/uomShare/wergProj/VegVisions/Outputs/Differences.xlsx", col.names = TRUE)
#ee_vv_diff2 <-subset(ee_vv_diff, diff!=0)

Fig_diff <- ggplot(data = ee_vv_diffhigh) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(aes(color = diff), size = 4) +
  scale_colour_gradient(low = "red", high = "green", breaks = c(-2,-1,0,1,2,3), 
      labels=c("-2 = VV21 lower than VV18 score", "-1 = VV21 slightly lower than VV18 score", "0 = No change", "1 = VV18 slightly higher than VV21 score", "2 = VV18 higher than VV21 score", 
               "3 = VV18 much higher than VV21 score")) +
  #scale_colour_gradient(low = "red", high = "green", breaks = c(-2,-1,0,1,2,3))+
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) +  
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
              pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
              style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Score difference"))
Fig_diff
ggsave('~/uomShare/wergProj/VegVisions/Outputs/VV_EE_diff.jpeg', 
       Fig_diff, device = "png", width = 13, height = 6, dpi = 300)

#figure showing stream reaches with highly different scores
high_ee2 <- st_join(MW_expProjhigh, points_buff_20m, left = FALSE)
ee_vv_data_high2 <- ee_vv_diffhigh %>% distinct(site_siteid, vv_vv_score, .keep_all = TRUE)
ee_vv_diffhigh2 <- ee_vv_data_high2 %>% 
  group_by(site_siteid, CATCHMENT.x, SUBCATCHME, LABEL, vv_vv_score, X_030_VV) %>%
  summarise(diff=vv_vv_score-X_030_VV)
reaches_filter <- ee_vv_diffhigh2 %>%
  filter(diff == "3" | diff == "2"| diff == "-2")

Fig_reach <- ggplot(data = reaches_filter) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(data = waterways, fill = "NA", colour = "blue", size = 0.4) +
  geom_sf(aes(color = diff), size = 4) +
  scale_colour_gradient(low = "red", high = "green", 
                        #scale_color_viridis(option = "turbo", direction = -1,
                        breaks = c(-2,2,3), labels=c("-2 = VV21 lower than VV18 score", "2 = VV18 higher than VV21 score", "3 = VV18 much higher than VV21 score")) +
  #scale_colour_gradient(low = "red", high = "green", breaks = c(-2,2,3))+
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) +  
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Score difference"))
Fig_reach
ggsave('~/uomShare/wergProj/VegVisions/Outputs/reach_diff.jpeg', 
       Fig_reach, device = "png", width = 13, height = 6, dpi = 300)

#mytable <- reaches_filter %>%
#select(site_siteid, CATCHMENT.x, LABEL, SUBCATCHME, vv_vv_score, #X_030_VV, diff)
write.xlsx2(as.data.frame(reaches_filter),"~/uomShare/wergProj/VegVisions/Outputs/reach_ee_vv_high.xlsx", col.names = TRUE)

ggplot(ee_vv_diffhigh, aes(x = diff)) +
  geom_histogram() +
  #scale_y_log10() +
  facet_wrap(~ CATCHMENT.x)+
  xlab("Difference") +
  ylab("Count of sites")+ theme_classic()

violin_plot <- ggplot(ee_vv_diffhigh, aes(x=CATCHMENT.x, y=diff)) + 
  geom_violin() + geom_jitter(shape=16, position=position_jitter(0)) +
  xlab("Catchment") +
  ylab("Difference between VV & Expert Elicited data")+ theme_classic()
ggsave('~/uomShare/wergProj/VegVisions/Outputs/diff_violin.jpeg', 
       violin_plot, device = "jpeg", dpi = 300)
```
  
```{data threats, r warning=FALSE}
pal <- wes_palette("Zissou1", 100, type = "continuous")
# Invasive weed scores
Fig_invWeeds <- ggplot(data = dat2) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = woody_weeds, fill = "blue", colour = "blue", size = 1) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  #geom_sf(data = vv_expertelic, fill = "NA", color = "red") +
  geom_sf(aes(color = ww_highlyinvasive_score), size = 2.5) +
  scale_colour_gradient(low = "yellow", high = "red", limits = c(0,5),
      labels=c("0 = No Invasive Weeds","1 = Very Low Invasive Weeds","2 = Low Invasive Weeds",
      "3 = Moderate Invasive Weeds","4 = High Invasive Weeds","5 = Very High Invasive Weeds")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Invasive Weed Score"))
Fig_invWeeds
ggsave('~/uomShare/wergProj/VegVisions/Outputs/vv_scores_invweeds.jpeg', 
       Fig_invWeeds, device = "png", width = 13, height = 6, dpi = 300)
# F Weediness scores
Fig_Weeds <- ggplot(data = dat2) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(aes(color = vv_F_weediness_score), size = 2.5) +
  scale_colour_gradient(low = "red", high = "yellow", limits = c(0,5), 
  labels=c("5 = Very High Weeds","4 = High Weeds","3 = Moderate Weeds",
  "2 = Low Weeds","1 = Very Low Weeds","0 = No Weeds")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Weediness Score"))
Fig_Weeds
ggsave('~/uomShare/wergProj/VegVisions/Outputs/vv_scores_weeds.jpeg', 
       Fig_Weeds, device = "png", width = 13, height = 6, dpi = 300)
WeedsVV_scores <- dat3 %>% dplyr::select(CATCHMENT, SUBCATCHME, vv_vv_score, vv_F_weediness_score, ww_highlyinvasive_score) %>%
  filter(vv_F_weediness_score <3, vv_vv_score>3)
WeedsVV_scores <- dat3 %>% dplyr::select(CATCHMENT, SUBCATCHME, vv_vv_score, vv_F_weediness_score, ww_highlyinvasive_score) %>%
  filter(vv_F_weediness_score <3, vv_vv_score>3)%>%
  count(CATCHMENT)
write.xlsx2(as.data.frame(WeedsVV_scores), file = "~/uomShare/wergProj/VegVisions/Outputs/WeedsVV_scores.xlsx", col.names = TRUE)
InvWeedsVV_scores <- dat3 %>% dplyr::select(CATCHMENT, SUBCATCHME, vv_vv_score, vv_F_weediness_score, ww_highlyinvasive_score) %>%
  filter(ww_highlyinvasive_score >3, vv_vv_score>3)
InvWeedsVV_scores <- dat3 %>% dplyr::select(CATCHMENT, SUBCATCHME, vv_vv_score, vv_F_weediness_score, ww_highlyinvasive_score) %>%
  filter(ww_highlyinvasive_score >3, vv_vv_score>3)%>%
  count(CATCHMENT)
write.xlsx2(as.data.frame(InvWeedsVV_scores), file = "~/uomShare/wergProj/VegVisions/Outputs/InvWeedsVV_scores.xlsx", col.names = TRUE)

#Counts of Deer and rabbit data from the VV threats data
vvthreats1 <- separate_rows(Corr_dat, vv_threats, sep = ",", convert = TRUE) 
vvthreats2 <- vvthreats1%>%
  dplyr::group_by(site_siteid, CATCHMENT, vv_vv_score) %>%
  dplyr::summarise(count = sum(!is.na(vv_threats)))

stock <- vvthreats1 %>% 
  group_by(site_siteid, CATCHMENT, vv_vv_score, vv_overall_score) %>%
  mutate(n = str_count(vv_threats, 'stock')) 
stock2 <- stock %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))
stock2$vv_vv_score <- as.numeric(stock2$vv_vv_score)
livestock<- stock2 %>%
  group_by(CATCHMENT) %>%
  dplyr::summarise(all = sum(n), avg = mean(vv_vv_score))
stock2$n <- as.numeric(stock2$n)
stock2$vv_overall_score <- as.factor(stock2$vv_overall_score)
stock2$vv_vv_score <- as.factor(stock2$vv_vv_score)
stock2$CATCHMENT <- as.factor(stock2$CATCHMENT)
str(stock2)

stockmodel = clm(vv_vv_score ~ n + CATCHMENT, data = stock2)
summary(stockmodel)
deer <- vvthreats1 %>% 
  group_by(site_siteid, CATCHMENT, vv_vv_score) %>%
  mutate(n = str_count(vv_threats, 'deer')) 
deer2 <- deer %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))
#deer2$vv_overall_score <- as.factor(deer2$vv_overall_score)
deer2$vv_vv_score <- as.factor(deer2$vv_vv_score)
deer2$CATCHMENT <- as.factor(deer2$CATCHMENT)
deermodel = clm(vv_vv_score ~ n + CATCHMENT, data = deer2)
summary(deermodel)

#Do a count of the high density deer sites
deer_threat <- vvthreats1 %>% 
  group_by(site_siteid, CATCHMENT, vv_vv_score) %>%
  mutate(n = str_count(vv_threats, 'deer')) 
deer_threat1 <- deer_threat %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))
Highdeer <- deer_threat1 %>%
  filter(n  == "1" | n  == "2"|n  == "3")

Deer_pelletmod <- raster ("~/uomShare/wergProj/riparian_deer/Melissa_2020/Models/quantileregression_vtcdnopop_onlysmoothed1km_April2022_63conf.tif")
Deer_pelletmod_reproj <- projectRaster(Deer_pelletmod,crs = crs(dat3))
# convert to a df for plotting in two steps,
# First, to a SpatialPointsDataFrame
Deer_pelletmod_pts <- rasterToPoints(Deer_pelletmod_reproj, spatial = TRUE)
# Then to a 'conventional' dataframe
Deer_pelletmod_df  <- data.frame(Deer_pelletmod_pts)
str(Deer_pelletmod_df)
rm(Deer_pelletmod_pts, Deer_pelletmod_reproj)
Fig_deermod <- ggplot() + 
  geom_raster(data = Deer_pelletmod_df, aes(fill = layer, x = x, y = y)) +
  scale_fill_gradientn(colors = rainbow(5), limits=c(0.2,3)) +
  geom_sf(data = Highdeer, fill = "NA", color = "blue", size = 2) +
  geom_sf(data = MW_4_5, fill ="NA", colour = "black", size = 1) +
  #(data = MW_bound, fill = "NA", color = "grey", size = 1) +
  geom_sf(data = MW_subcatchProj2, fill = "NA", color = "black", size = 1) +
  labs(fill = "Modelled Deer Density (Pellets)", x = 'Longitude', y = 'Latitude')
Fig_deermod
ggsave('~/uomShare/wergProj/VegVisions/Outputs/deer model.jpeg', 
       Fig_deermod, device = "png", width = 13, height = 6, dpi = 300)

scale_fill_gradientn(colours=c("white","yellow","orange","red", "dark red"),
                       values=c(0,0.2,0.3,1,3)
ggplot() + 
  geom_raster(data = Deer_pelletmod_df, aes(fill = layer, x = x, y = y)) +
  scale_fill_gradientn(colours=c("white","yellow","orange","red", "dark red"),
                       values=c(0,0.2,0.3,1,3)) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(data = Highdeer, fill = "NA", color = "blue", size = 2) +
  labs(fill = "Modelled Deer Density (Pellets)", x = 'Longitude', y = 'Latitude')         
                     
ggsave('~/uomShare/wergProj/VegVisions/Outputs/deer model.jpeg', 
       Fig_deermod, device = "png", width = 13, height = 6, dpi = 300)

#extract values at VV sites for deer modelling data with 50m buffer
deer_sites2 <- extract(Deer_pelletmod_reproj, deer_threat1, fun = mean, buffer = 50)
deer_threat1$preddeer <- deer_sites2
deer_threat1$binary <- ifelse(deer_threat1$n == 0, 0,1)
boxplot (preddeer~n, data = deer_threat1)
boxplot (preddeer~binary, data = deer_threat1)
describeBy (deer_threat1, group="n") psych
write.xlsx2(as.data.frame(deer_sites2), file = "~/uomShare/wergProj/VegVisions/Outputs/deer_sites2.xlsx", col.names = TRUE)
write.xlsx2(as.data.frame(Highdeer), file = "~/uomShare/wergProj/VegVisions/Outputs/polygons_deer_sites2.xlsx", col.names = TRUE)

FigDeer <- ggplot(deer_threat1[which(deer_threat1$n>0),]) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(aes(color = n), size = 2.5) +
  scale_colour_gradient(low = "yellow", high = "red", limits = c(0,3),
  labels=c("Not Detected", "1 Sign","2 Signs","3 Signs")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black", nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
  nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) +  
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
  pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
  style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Deer Signs Detected"))
FigDeer
ggsave('~/uomShare/wergProj/VegVisions/Outputs/deer threats.jpeg', 
       FigDeer, device = "png", width = 13, height = 6, dpi = 300)

deer_sites <- extract(Deer_pelletmod, dat3, fun = mean, buffer = 50)
#points_buff_50m <- st_buffer(join_Score_catch, 50)
#crs(points_buff_50m)
polygons <- st_transform(join_Score_catch, crs = crs(Deer_pelletmod))
deer_sites <- extract(Deer_pelletmod, polygons, fun = mean, buffer = 50)
output = data.frame(deer_sites)
print(output)
write.xlsx2(as.data.frame(deer_sites), file = "~/uomShare/wergProj/VegVisions/Outputs/deer_sites.xlsx", col.names = TRUE)
write.xlsx2(as.data.frame(polygons), file = "~/uomShare/wergProj/VegVisions/Outputs/polygons_deer_sites.xlsx", col.names = TRUE)

plot(Deer_pelletmod, breaks = c(0.2, 0.3, 0.6, 1, 3, 10), col = terrain.colors(4), main = "sample points sized by surface temperature")
plot(deer_sites, pch = 19, add = TRUE) 
# size the points according to the value

# Rabbit threats
rabbit_threat <- vvthreats1 %>% 
  group_by(site_siteid, CATCHMENT.x) %>%
  mutate(n = str_count(vv_threats, 'rabbit')) 
rabbit_threat1 <- rabbit_threat %>%
  summarise(n = sum(n)) %>% 
  replace_na(list(n = 0))

FigRabbit <- ggplot(rabbit_threat1[which(rabbit_threat1$n>0),]) +
  geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = MW_4_5, fill =alpha("red",0.2), colour = NA) +
  #geom_sf(data = Current_veg, fill = "lightgreen", colour = NA) +
  #geom_sf(data = Urb_grow, fill = "darkgrey", colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "black", size = 1) +
  geom_sf(aes(color = n), size = 2.5) +
  scale_colour_gradient(low = "orange", high = "red",
                        breaks = c(0,1,2), labels=c("Not Detected", "1 Sign","2 Signs")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.615, -0.3, -0.36),
               nudge_y = c(-0.05, 0.2, 0.01, 0.4, 0.3)) +  
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Rabbit Signs Detected"))
FigRabbit
ggsave('~/uomShare/wergProj/VegVisions/Outputs/rabbit threats.jpeg', 
       FigRabbit, device = "png", width = 13, height = 6, dpi = 300)
```



Fig1 <- ggplot(data = dat2) +
  # geom_sf(data = MW_4_5, fill = "green", colour = NA) +
  # geom_sf(data = MW_priority, fill = "grey", colour = NA) +
  geom_sf(data = Current_veg, fill = "lightgreen", colour = NA) +
  geom_sf(data = Urb_grow, fill = "darkgrey", colour = NA) +
  geom_sf(data = MW_bound, fill = "NA", color = "blue") +
  geom_sf(aes(color = vv_C_instreamveg_score), size = 3) +
  scale_color_viridis(option = "A", direction = -1,limits = c(0,5), labels=c("0 = Absent", "1 = Very Low", "2 = Low","3 = Medium","4 = High", "5 = Very High")) +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.63, -0.3, -0.32),
               nudge_y = c(-0.05, 0.2, 0.2, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Instream vegetation Score"))
Fig1

Fig2 <- ggplot(data = dat2) +
  geom_sf(aes(color = vv_A_structure_score), size = 3) +
  scale_color_viridis(option = "A", direction = -1) +
  geom_sf(data = MW_bound, fill = "NA", color = "blue") +
  geom_sf_text(data = MW_bound, aes(label = CATCHMENT), colour = "black",
               nudge_x =c(-0.3, 0.2, 0.63, -0.3, -0.32),
               nudge_y = c(-0.05, 0.2, 0.2, 0.4, 0.3)) + 
  annotation_scale(location = "bl", width_hint = 0.4) +
  annotation_north_arrow(location = "bl", which_north = "true", 
                         pad_x = unit(0.75, "in"), pad_y = unit(0.5, "in"),
                         style = north_arrow_fancy_orienteering) +
  xlab("Longitude") + ylab("Latitude") + theme_classic() +
  guides(colour=guide_legend(title = "Structure Score", labels = c("Very Low")))

ee_vv1 <- join_Score_catch3%>%
  group_by(site_siteid, CATCHMENT.x) %>%
  summarise(count = sum(!is.na(vv_threats)) 
  )

catchcount <- join_catch %>% count(CATCHMENT, vv_vv_score)
catchcount <- join_catch %>% count(SUBCATCHME, vv_vv_score)

#Histogram of sites with each VV score
ggplot(join_catch, aes(x = vv_vv_score)) +
  geom_histogram() +
  facet_wrap(~ CATCHMENT.x, scales = "free")+
  xlab("Vegetation Visions Score") +
  ylab("Count of sites")+ theme_classic()

# Histogram of subcatchments, focusing on each individual catchment
Maribyrnong <- filter(join_catch, CATCHMENT.x == "Maribyrnong")
count <- Yarra %>% count(SUBCATCHME, vv_vv_score)
ggplot(Maribyrnong, aes(x = vv_vv_score)) +
  geom_histogram() +
  facet_wrap(~ SUBCATCHME) + 
  scale_x_continuous(breaks = seq(0:5)) +
  xlab("Vegetation Visions Score") +
  ylab("Count of sites")+ theme_classic()



###


```{r warning=FALSE}

```

